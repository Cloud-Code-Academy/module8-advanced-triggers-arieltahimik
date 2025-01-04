public with sharing class OpportunityTriggerHandler extends TriggerHandler {

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

    //* Part 2 - Another Opportunity Triggers

    public override void beforeInsert() {
        // Set default Type for new Opportunities
        OpportunityHelper.setType(newOppList);
    }

    public override void beforeDelete() {
        // Prevent deletion of closed Opportunities
        OpportunityHelper.validateCloseOpportunity(oldOppList);
    }

    public override void afterInsert() {
        // Create a new Task for newly inserted Opportunities
        OpportunityHelper.insertTask(newOppList);
    }    
    
    public override void beforeUpdate() {
        // Append Stage changes in Opportunity Description
        //OpportunityHelper.updateDescriptionFromStage(Trigger.new, Trigger.oldMap); // <-- This doesn't work        
        OpportunityHelper.updateDescriptionFromStage(newOppList, oldOppMap);

        for(Opportunity opp : this.newOppList) {
            //* When an opportunity is updated validate that the amount is greater than 5000.    
            if(opp.Amount < 5000){
                opp.addError('Opportunity amount must be greater than 5000');
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

    public override void afterDelete() {
        // Send email notifications when an Opportunity is deleted 
        OpportunityHelper.notifyOwnersOpportunityDeleted(oldOppList);
    }

    public override void afterUndelete() {
        // Assign the primary contact to undeleted Opportunities
        OpportunityHelper.assignPrimaryContact(newOppMap);
    }
}