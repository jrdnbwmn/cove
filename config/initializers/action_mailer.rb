ActiveSupport.on_load(:action_mailer) do
  add_delivery_method :loops, LoopsDelivery
end
