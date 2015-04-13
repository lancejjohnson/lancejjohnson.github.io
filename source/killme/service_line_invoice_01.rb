require_relative 'stratus_facade'
require_relative 'service_line_facade'
require_relative 'service_line_data'

class ServiceLineInvoice < StratusFacade
  def self.new_collection(data:)
    attach_service_lines!(super)
  end

  def invoice_items
    @invoice_items ||= builder.collection(
      data: data.invoice_items,
      klass: :invoice_item
    )
  end

  private

  # service_line_invoice_01.rb
  def self.attach_service_lines!(invoices)
    invoices.each_with_index do |invoice, index|
      add_service_lines_to_invoice_items!(invoice.invoice_items)
      reset_service_lines if index == (invoices.count - 1)
    end
  end

  def self.add_service_lines_to_invoice_items!(invoice_items)
    invoice_items.each do |invoice_item|
      add_service_line_to_invoice_item!(invoice_item)
    end
  end

  def self.add_service_line_to_invoice_item!(invoice_item)
    if invoice_item.subscription
      if id = invoice_item.subscription.service_line_id
        invoice_item.service_line = service_line_by_id(id)
      end
    end
  end

  def self.service_line_by_id(id)
    service_lines.detect {|sl| sl.id == id } || get_service_line(id)
  end

  def self.get_service_line(id)
    service_line = ServiceLineFacade.new(data: ServiceLineData.find_by_id(id))
    cache_service_line(service_line)
  end

  def self.cache_service_line(service_line)
    service_line.tap { |sl| service_lines << sl }
  end

  def self.service_lines
    @@service_lines ||= []
  end

  def self.reset_service_lines
    @@service_lines = []
  end
end
