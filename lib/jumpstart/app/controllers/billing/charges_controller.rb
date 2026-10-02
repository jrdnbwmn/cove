class Billing::ChargesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_charge

  def show
    respond_to do |format|
      format.pdf {
        if stale?(@charge, etag: current_account.updated_at)
          send_data @charge.receipt,
            filename: @charge.receipt_filename,
            type: "application/pdf",
            disposition: :inline
        end
      }
    end
  end

  def invoice
    respond_to do |format|
      format.pdf {
        if stale?(@charge, etag: current_account.updated_at)
          send_data @charge.invoice,
            filename: @charge.invoice_filename,
            type: "application/pdf",
            disposition: :inline
        end
      }
    end
  end

  # AIDEV-NOTE: Receipts and invoices include the family's billing details, so the ETag
  # also keys on the account's updated_at, not just the charge.
  private

  def set_charge
    @charge = current_account.pay_charges.find_by_prefix_id!(params[:id])
  end
end
