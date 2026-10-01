module Pay
  class Subscription
    module PlanSchedule
      # Only yearly -> monthly is deferred to renewal; every other change is an immediate prorated swap.
      def plan_change_at_renewal?(target_plan)
        stripe? && plan&.yearly? && target_plan.monthly?
      end

      # AIDEV-NOTE: This builds a yearly -> monthly schedule only (one monthly phase after the current
      # period), so it is guarded by plan_change_at_renewal? in the controller rather than derived from the plan.
      def schedule_plan_change_at_renewal(plan)
        schedule = ::Stripe::SubscriptionSchedule.create({from_subscription: processor_id}, stripe_options)

        ::Stripe::SubscriptionSchedule.update(schedule.id, {
          end_behavior: "release",
          proration_behavior: "none",
          phases: [
            {
              items: [{price: processor_plan, quantity: quantity}],
              start_date: current_period_start.to_i,
              end_date: current_period_end.to_i,
              proration_behavior: "none"
            },
            {
              items: [{price: plan.stripe_id, quantity: quantity}],
              duration: {interval: "month", interval_count: 1},
              proration_behavior: "none"
            }
          ]
        }, stripe_options)

        sync!
        clear_pending_plan_change
      rescue ::Stripe::StripeError => error
        ::Stripe::SubscriptionSchedule.release(schedule.id, {}, stripe_options) if schedule
        raise Pay::Error, error
      end

      # Cheap check for views that only need to know whether a switch is pending (no Plan lookup).
      def pending_plan_change?
        future_schedule_phase.present?
      end

      # AIDEV-NOTE: Memoized because billing views and controller guards call it several times per request.
      # Cleared after every sync! that changes the schedule. Stripe-only: it matches the phase's price against
      # Plan#stripe_id.
      def pending_plan_change
        return @pending_plan_change if @pending_plan_change_loaded

        @pending_plan_change_loaded = true
        @pending_plan_change = build_pending_plan_change
      end

      def release_schedule!
        return unless stripe?

        schedule_id = stripe_schedule_id
        return if schedule_id.blank?

        ::Stripe::SubscriptionSchedule.release(schedule_id, {}, stripe_options)
        sync!
        clear_pending_plan_change
      rescue ::Stripe::StripeError => error
        raise Pay::Error, error
      end

      private

      def stripe_options
        {stripe_account: stripe_account}.compact
      end

      # Pay expands "schedule" on sync, so the stored object holds a Hash; an unexpanded schedule is just an ID string.
      def stripe_schedule
        schedule = object&.fetch("schedule", nil)
        schedule if schedule.is_a?(Hash)
      end

      def stripe_schedule_id
        schedule = object&.fetch("schedule", nil)
        schedule.is_a?(Hash) ? schedule["id"] : schedule
      end

      # A "future" phase is one that has not started yet, i.e. the switch that is still pending.
      def future_schedule_phase
        stripe_schedule&.fetch("phases", [])&.find { |phase| phase["start_date"].to_i > Time.current.to_i }
      end

      def build_pending_plan_change
        future_phase = future_schedule_phase
        return unless future_phase

        price = future_phase.dig("items", 0, "price")
        price = price["id"] if price.is_a?(Hash)
        plan = ::Plan.find_by(stripe_id: price)
        return unless plan

        {plan: plan, starts_at: Time.zone.at(future_phase["start_date"])}
      end

      def clear_pending_plan_change
        @pending_plan_change_loaded = false
        @pending_plan_change = nil
      end
    end
  end
end
