###############################################################################
#
#    OERPScenario, OpenERP Functional Tests
#    Copyright 2009 Camptocamp SA
#
##############################################################################
##############################################################################
# Branch      # Module       # Processes     # System
@addons       @account_voucher       @account_voucher_run   @account_voucher_test

Feature: In order to validate multicurrency account_voucher behaviour as an admin user I do a reconciliation run.
         I want to create a supplier invoice for 1000 USD (rate : 1.5) and pay it in full in USD (rate : 1.8)
         with account_voucher. The Journal entries must calculate the correct currency gain/loss.

  @account_voucher_run
  Scenario: Create invoice 103
  Given I need a "account.invoice" with oid: scen.voucher_inv_103
    And having:
      | name               | value                              |
      | name               | SI_103                             |
      | date_invoice       | %Y-01-01                           |
      | date_due           | %Y-02-15                           |
      | address_invoice_id | by oid: scen.voucher_partner_add   |
      | partner_id         | by oid: scen.voucher_partner       |
      | account_id         | by name: Creditors - (test)        |
      | journal_id         | by name: Expenses Journal - (test) |
      | currency_id        | by name: USD                       |
      | type               | in_invoice                         |


    Given I need a "account.invoice.line" with oid: scen.voucher_inv103_line103
    And having:
      | name       | value                           |
      | name       | invoice line 103                |
      | quantity   | 1                               |
      | price_unit | 1000                            |
      | account_id | by name: Product Sales - (test) |
      | invoice_id | by oid:scen.voucher_inv_103     |
    Given I find a "account.invoice" with oid: scen.voucher_inv_103
    And I open the credit invoice

  @account_voucher_run
  Scenario: Create Statement 103
    Given I need a "account.bank.statement" with oid: scen.voucher_statement_103
    And having:
     | name        | value                             |
     | name        | Bk.St.103                         |
     | date        | %Y-02-15                          |
     | currency_id | by name: USD                      |
     | journal_id  | by oid:  scen.voucher_usd_journal |
    And the bank statement is linked to period "X 02/%Y"


 @account_voucher_run @account_voucher_import_invoice
  Scenario: Import invoice into statement
    Given I find a "account.bank.statement" with oid: scen.voucher_statement_103
    And I import invoice "SI_103" using import invoice button

  @account_voucher_run @account_voucher_confirm
  Scenario: confirm bank statement (/!\ Voucher payment options must be 'reconcile payment balance' by default )
    Given I find a "account.bank.statement" with oid: scen.voucher_statement_103
    And I set bank statement end-balance
    When I confirm bank statement

  @account_voucher_run @account_voucher_valid_103
  Scenario: validate voucher
    Given I find a "account.bank.statement" with oid: scen.voucher_statement_103
    Then I should have following journal entries in voucher:
      | date     | period  | account                        |  debit | credit | curr.amt | curr. | reconcile | partial |
      | %Y-02-15 | X 02/%Y | Foreign Exchange Gain - (test) |        | 111.11 |          | USD   |           |         |
      | %Y-02-15 | X 02/%Y | Creditors - (test)             | 111.11 |        |          | USD   | yes       |         |
      | %Y-02-15 | X 02/%Y | Creditors - (test)             | 555.56 |        |     1000 | USD   | yes       |         |
      | %Y-02-15 | X 02/%Y | USD bank account               |        | 555.56 |    -1000 | USD   |           |         |

  @account_voucher_run @account_voucher_valid_invoice_103
  Scenario: validate voucher
    Given My invoice "SI_103" is in state "paid" reconciled with a residual amount of "0.0"