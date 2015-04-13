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

  def self.attach_service_lines!(invoices)
    invoices.each do |invoice|
      invoice.invoice_items.each do |invoice_item|
        if invoice_item.subscription
          if id = invoice_item.subscription.service_line_id
            invoice_item.service_line = get_service_line(id)
          end
        end
      end
    end
  end

  def self.get_service_line(id)
    unless service_line = service_lines.detect { |sl| sl.id == id }
      service_line = ServiceLineFacade.new(data: ServiceLineData.find_by_id(id))
      service_lines << service_line
    end

    service_line
  end

  def self.service_lines
    @@service_lines ||= []
  end

  def self.reset_service_lines
    @@service_lines = []
  end
end
