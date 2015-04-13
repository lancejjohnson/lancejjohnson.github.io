describe ServiceLineInvoice do
  describe "new_collection" do
    before do
      # For the sake of brevity, I've excluding some mocking
      # and json fixture data here.
      @invoices = ServiceLineInvoice.new_collection(data: invoice_data)
    end

    it "attaches service lines to invoice items with an id" do
      @invoices[0..1].each do |invoice|
        invoice.invoice_items.each do |item|
          expect(item.service_line).to be
        end
      end
    end

    it "does not attach service lines to invoice items without an id" do
      @invoices[2].invoice_items.each do |item|
        expect(item.service_line).to be_nil
      end
    end

    it "attaches the correct service line to invoice items with an id" do
      invoice_item = @invoices.first.invoice_items.first
      expect(invoice_item.service_line.id).to eql "abcdef1234"
    end
  end
end
