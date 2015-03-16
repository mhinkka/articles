package my;

import java.io.Serializable;

public class Event implements Serializable {
    private String eventId;
    private String caseId;
    private String event;
    private String tstamp;

    public String getEventId() {
	return eventId;
    }

    public void setEventId(String eventId) {
	this.eventId = eventId;
    }

    public String getCaseId() {
	return caseId;
    }

    public void setCaseId(String caseId) {
	this.caseId = caseId;
    }

    public String getEvent() {
	return event;
    }

    public void setEvent(String event) {
	this.event = event;
    }

    public String getTstamp() {
	return tstamp;
    }

    public void setTstamp(String tstamp) {
	this.tstamp = tstamp;
    }
}
