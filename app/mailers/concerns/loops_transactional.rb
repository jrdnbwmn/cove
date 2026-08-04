module LoopsTransactional
  private

  def loops_transactional_id(name)
    Rails.application.config_for(:loops).transactional.fetch(name)
  end
end
