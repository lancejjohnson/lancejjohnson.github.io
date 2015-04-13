require_relative 'stratus_facade'
require_relative 'attaches_service_lines_to_invoices'
require_relative 'service_line_facade'
require_relative 'service_line_data'

class ServiceLineInvoice < StratusFacade
  def self.new_collection(data:)
    attacher.attach_service_lines!(super)
  end

  def attach_service_lines
    self.class.attacher.attach_service_lines!([self]).first
  end

  def invoice_items
    @invoice_items ||= builder.collection(
      data: data.invoice_items,
      klass: :invoice_item
    )
  end

  def recurring_items
    invoice_items.select(&:recurring_item?)
  end

  def non_recurring_items
    invoice_items.select(&:non_recurring_item?)
  end

  def usage_items
    invoice_items.select(&:usage_item?)
  end

  private

  def self.attacher
    AttachesServiceLinesToInvoices.new(
      klass: ServiceLineFacade,
      data_source: ServiceLineData
    )
  end
end
