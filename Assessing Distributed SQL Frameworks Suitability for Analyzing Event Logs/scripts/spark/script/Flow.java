package my;

import java.io.Serializable;
import java.text.ParseException;
import java.text.SimpleDateFormat;

public class Flow implements Serializable {
    private String caseId;
    private String fromEvent;
    private String toEvent;
    private String fromTimestamp;
    private String toTimestamp;
    private Double duration;

    public Flow(String caseId, String fromEvent, String toEvent, 
		String fromTimestamp, String toTimestamp)
    {
	this.caseId = caseId;
	this.fromEvent = fromEvent;
	this.toEvent = toEvent;
	this.fromTimestamp = fromTimestamp;
	this.toTimestamp = toTimestamp;

	final SimpleDateFormat formatter = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS");

	if ((fromTimestamp != null && !fromTimestamp.trim().equals("")) &&
	    (toTimestamp != null && !toTimestamp.trim().equals(""))) {
	    try {
		this.duration = new Double(formatter.parse(toTimestamp).getTime() - formatter.parse(fromTimestamp).getTime()) / 1000;
	    }
	    catch (ParseException e) {
		this.duration = 0.0;
	    }
	}
	else
	    this.duration = 0.0;
    }

    public String getCaseId() {
	return caseId;
    }

    public void setCaseId(String caseId) {
	this.caseId = caseId;
    }

    public String getFromEvent() {
	return fromEvent;
    }

    public void setFromEvent(String event) {
	this.fromEvent = event;
    }

    public String getToEvent() {
	return toEvent;
    }

    public void setToEvent(String event) {
	this.toEvent = event;
    }

    public String getFromTimestamp() {
	return fromTimestamp;
    }

    public void setFromTimestamp(String timestamp) {
	this.fromTimestamp = timestamp;
    }

    public String getToTimestamp() {
	return toTimestamp;
    }

    public void setToTimestamp(String timestamp) {
	this.toTimestamp = timestamp;
    }

    public Double getDuration() {
	return duration;
    }
}
