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

    // Trigger Contexts

    public override void beforeInsert() {
        // Set default Type for new Opportunities
        OpportunityHelper.setType(newOppList);
    }

    public override void beforeDelete() {
        // Prevent deletion of closed Opportunities
        OpportunityHelper.validateCloseOpportunity(oldOppList);

        // Prevent deletion of a closed won opportunity if the account industry is 'Banking'.
        OpportunityHelper.deleteCloseWonOpportunity(oldOppList);
    }

    public override void beforeUpdate() {
        // Append Stage changes in Opportunity Description
        // OpportunityHelper.updateDescriptionFromStage(Trigger.new, Trigger.oldMap); // <-- This doesn't work        
        OpportunityHelper.updateDescriptionFromStage(newOppList, oldOppMap);

        // When an opportunity is updated validate that the amount is greater than 5000.
        OpportunityHelper.amountValidation(newOppList);


        // When an opportunity is updated set the primary contact on the opportunity to the contact with the title of 'CEO'.
        OpportunityHelper.setPrimaryContact(newOppList);
    }

    public override void afterInsert() {
        // Create a new Task for newly inserted Opportunities
        OpportunityHelper.insertTask(newOppList);
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