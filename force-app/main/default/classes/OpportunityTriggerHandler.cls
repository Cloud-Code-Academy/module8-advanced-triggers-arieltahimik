public with sharing class OpportunityTriggerHandler extends TriggerHandler{

    // Private Collection Variables

    private List<Opportunity> newOppList;
    private List<Opportunity> oldOppList;
    private Map<Id, Opportunity> newOppMap;
    private Map<Id, Opportunity> oldOppMap;

    // Constructor
    public OpportunityTriggerHandler() {
        this.newOppList = (List<Opportunity>) Trigger.new;
        this.oldOppList = (List<Opportunity>) Trigger.old;
        this.newOppMap = (Map<Id,Opportunity>) Trigger.newMap;
        this.oldOppMap = (Map<Id,Opportunity>) Trigger.oldMap;        
    }

    //* Opportunity Triggers

    public override void beforeInsert() {
        // Set default Type for new Opportunities
        for (Opportunity opp : this.newOppList) {
            if (opp.Type == null){
                opp.Type = 'New Customer';
            }
        }
    }

    public override void afterInsert() {
        //* Create a new Task for newly inserted Opportunities
        List<Task> tasks = new List<Task>();
        for (Opportunity opp : this.newOppList){
            Task tsk = new Task();
            tsk.Subject = 'Call Primary Contact';
            tsk.WhatId = opp.Id;
            tsk.WhoId = opp.Primary_Contact__c;
            tsk.OwnerId = opp.OwnerId;
            tsk.ActivityDate = Date.today().addDays(3);
            tasks.add(tsk);
        }
        if (tasks.size() != 0) {
            insert tasks;
        }
    }    
    
    public override void beforeUpdate() {
        for(Opportunity opp : this.newOppList){
            //* When an opportunity is updated validate that the amount is greater than 5000.    
            if(opp.Amount < 5000){
                opp.addError('Opportunity amount must be greater than 5000');
            }
            
            //* Append Stage changes in Opportunity Description
            Opportunity oldOpp = this.oldOppMap.get(opp.Id);
            if (opp.StageName != oldOpp.StageName) {
                opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
            }
        }

        //* SET PRIMARY CONTACT
        //Get contacts related to the opportunity account
        Set<Id> accountIds = new Set<Id>();
        for(Opportunity opp : this.newOppList){
            accountIds.add(opp.AccountId);
        }
        
        Map<Id, Contact> contacts = new Map<Id, Contact>([SELECT Id, FirstName, AccountId FROM Contact WHERE AccountId IN :accountIds AND Title = 'CEO' ORDER BY FirstName ASC]);
        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();

        for (Contact cont : contacts.values()) {
            if (!accountIdToContact.containsKey(cont.AccountId)) {
                accountIdToContact.put(cont.AccountId, cont);
            }
        }

        for(Opportunity opp : this.newOppList){
            if(opp.Primary_Contact__c == null){
                if (accountIdToContact.containsKey(opp.AccountId)){
                    opp.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
                }
            }
        }
    }

    public override void beforeDelete() {
        //* Prevent deletion of closed Opportunities
        //* When an opportunity is deleted prevent the deletion of a closed won opportunity if the account industry is 'Banking'.
        Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id, Industry FROM Account WHERE Id IN (SELECT AccountId FROM Opportunity WHERE Id IN :this.oldOppList)]);
        for(Opportunity opp : this.oldOppList) {
            if((opp.StageName == 'Closed Won' && accounts.get(opp.AccountId).Industry == 'Banking') || (opp.IsClosed)){
                opp.addError('Cannot delete closed opportunity');
            }
        }
    }

    public override void afterDelete() {
        //* Send email notifications when an Opportunity is deleted 
        notifyOwnersOpportunityDeleted(this.oldOppList);
    }

    public override void afterUndelete() {
        //* Assign the primary contact to undeleted Opportunities
        assignPrimaryContact(this.newOppMap);
    }


    /*
    notifyOwnersOpportunityDeleted:
    - Sends an email notification to the owner of the Opportunity when it gets deleted.
    - Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    */
    private static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        Map<Id, User> userMap = new Map<Id, User>([SELECT Id, Email FROM User]);
        for (Opportunity opp : opps){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();            
            //String[] toAddresses = new String[] {[SELECT Id, Email FROM User WHERE Id = :opp.OwnerId].Email};
            User owner = userMap.get(opp.OwnerId);
            String[] toAddresses = new List<String>{ owner.Email };
            mail.setToAddresses(toAddresses);
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }        
        
        try {
            Messaging.sendEmail(mails);
        } catch (Exception e){
            System.debug('Exception: ' + e.getMessage());
        }
    }

    /*
    assignPrimaryContact:
    - Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
    - Only updates the Opportunities that don't already have a primary contact.
    */
    private static void assignPrimaryContact(Map<Id,Opportunity> oppsMap) {
        // Get all Account Ids from the opportunities
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : oppsMap.values()) {
            accountIds.add(opp.AccountId);  
        }

        // Query contacts from accountIds with Title 'VP Sales'
        List<Contact> primaryContacts = [SELECT Id, AccountId FROM Contact WHERE Title = 'VP Sales' AND AccountId = :accountIds];
        Map<Id, Contact> accIdToConMap = new Map<Id, Contact>();
        for (Contact con : primaryContacts) {
            accIdToConMap.put(con.AccountId,con);
        }

        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        for (Opportunity opp : oppsMap.values()){            
            //Contact primaryContact = [SELECT Id, AccountId FROM Contact WHERE Title = 'VP Sales' AND AccountId = :opp.AccountId LIMIT 1];
            if (opp.Primary_Contact__c == null){
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                Contact primaryContact = accIdToConMap.get(opp.AccountId);
                oppToUpdate.Primary_Contact__c = primaryContact.Id;
                //oppToUpdate.Primary_Contact__c = accIdToConMap.get(opp.AccountId).Id;
                oppMap.put(opp.Id, oppToUpdate);
            }
        }
        update oppMap.values();
    }
}