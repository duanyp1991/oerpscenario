Given /^I correct the period default set up \(all special by default\) :$/ do
  p_ids =  AccountPeriod.search([['fiscalyear_id', '=', 1]])
  if p_ids
    AccountPeriod.write(p_ids, {'special'=> false})
  end
end

Given /^I set the following currency rates :$/ do |table|
   table.hashes.each do |row|
    date =  Time.new().strftime(row['date'])
    currency = ResCurrency.find_by_name(row['currency'], :fields=>['id'])
    currency.should_not be_nil,
    "Could not find curreny #{row['currency']}"
    curr_rate = ResCurrencyRate.find_by_name_and_currency_id(date, currency.id)
    unless curr_rate
      puts " creating new rate"
      curr_rate = ResCurrencyRate.new
      curr_rate.name = date
      curr_rate.currency_id = currency.id
    end
    curr_rate.rate = row['rate']
    curr_rate.save
   end

end

Given /^I allow cancelling entries on all journals$/ do
  j_ids =  AccountJournal.search([])
  if j_ids
    AccountJournal.write(j_ids, {'update_posted'=> true})
  end
end

Given /^I open the credit invoice$/ do
 @found_item.should_not be_nil,
  "no invoice found"
 ['draft', 'open'].should include(@found_item.state),
  "Invoice is not draf or open"
 if @found_item.state == 'draft'
   @found_item.wkf_action('invoice_open')
 end
end

Given /^I import invoice "(.*?)" using import invoice button$/ do |inv_name|
  invoice_to_import = AccountInvoice.find_by_name(inv_name)
  invoice_to_import.should_not be_nil,
  "Can't find invoice #{inv_name}"
  @found_item.should_not be_nil, "No statement find"
  @found_item.is_a?(AccountBankStatement).should be_true, "found item is not a bank statement"
  @found_item.line_ids.each do |line|
    line.destroy
  end
  wiz = AccountStatementFromInvoiceLines.new()
  acc_id = invoice_to_import.account_id.id
  invoice_to_import.move_id.should_not be_nil
  move_id = invoice_to_import.move_id.id
  lines = AccountMoveLine.search([['move_id', '=', move_id], ['account_id', '=', acc_id]])
  lines.should_not be_empty, "Could not find line to import"
  wiz.line_ids = lines
  wiz.save
  wiz.populate_statement({'statement_id'=>@found_item.id})
end


Given /^I set voucher balance$/ do
  @found_item.should_not be_nil, "No statement find"
  @found_item.is_a?(AccountBankStatement).should be_true, "found item is not a bank statement"
  @found_item.balance_end_real = @found_item.balance_end
  @found_item.save
  @found_item = AccountBankStatement.find(@found_item.id)
  @found_item.balance_end.should eq @found_item.balance_end_real
end

When /^I confirm voucher$/ do
   @found_item.should_not be_nil, "No statement find"
   @found_item.is_a?(AccountBankStatement).should be_true, "found item is not a bank statement"
   @found_item.button_confirm_bank
end

Then /^I should have following journal entries in voucher:$/ do |table|
  h_list = table.hashes
  h_list.each do | h |
    h.each {|k, v| h[k] = false if v.empty?}
  end
  @found_item.should_not be_nil, "No statement find"
  @found_item.is_a?(AccountBankStatement).should be_true, "found item is not a bank statement"
  @found_item.move_line_ids.length.should eq h_list.length,
  "We should have #{h_list.length} lines  but we have #{@found_item.move_line_ids.length}"
  errors = []
  # we can use inverse approach
  h_list.each do | row |
    account = AccountAccount.find_by_name(row['account'], :fields=>['id'])
    account.should_not be_nil, "no account named #{row['account']} found"
    pname = Time.new().strftime(row['period'])
    period = AccountPeriod.find_by_name(pname, :fields=['id'])
    period.should_not be_nil, "no period #{pname} found"
    domain = [['account_id', '=', account.id], ['period_id', '=', period.id],
              ['date', '=', Time.new().strftime(row['date'])], ['reconcile_id', '=', row['reconcile']],
              ['reconcile_partial_id', '=', row['partial']], ['credit', '=', row.fetch('credit', 0.0)],
              ['debit', '=', row.fetch('debit', 0.0)],['amount_currency', '=', row.fetch('curr.amt', 0.0)],
              ['id', 'in', @found_item.move_line_ids.collect {|x| x.id}]]
    pp domain
    line = AccountMoveLine.find(:first, :domain=>domain)
    line.should_not be_nil, "Can not find line #{row.inspect}"
  end
end

Given /^My invoice "(.*?)" is in state "(.*?)" reconciled with a residual amount of "(.*?)"$/ do |inv_name, state, residual|
  invoice = AccountInvoice.find_by_name(inv_name)
  invoice.should_not be_nil, "Can't find invoice #{inv_name}"
  invoice.residual.should be_within(0.0001).of(residual.to_f) , "residual is #{invoice.residual} instead of #{residual}"
  invoice.state.should eq state
end
