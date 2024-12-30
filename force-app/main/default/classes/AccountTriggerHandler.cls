/*
AccountTrigger Overview

This trigger performs several operations on the Account object during its insertion. 
Depending on the values and conditions of the newly created Account, this trigger can:

1. Set the account's type to 'Prospect' if it's not already set.
2. Copy the shipping address of the account to its billing address.
3. Assign a rating of 'Hot' to the account if it has Phone, Website, and Fax filled.
4. Create a default contact related to the account after it's inserted.
*/

public with sharing class AccountTriggerHandler extends TriggerHandler {

    public override void beforeInsert() {
        AccountHelper.setTypeProspect(Trigger.new);
        AccountHelper.addressCopy(Trigger.new);
        AccountHelper.setRating(Trigger.new);
    }

    public override void afterInsert() {
        AccountHelper.defaultContact(Trigger.new);
    }

}