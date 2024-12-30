trigger AccountTrigger on Account (before insert, after insert) {
    new AccountTriggerHandler().run();
}