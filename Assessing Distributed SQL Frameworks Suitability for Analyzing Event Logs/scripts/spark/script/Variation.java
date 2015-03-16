package my;

import java.io.Serializable;

public class Variation implements Serializable {
    private Integer eventCount;
    private String eventTypes;

    public Variation(Integer eventCount)
    {
	this.eventCount = eventCount;
    }

    public Integer getEventCount() {
	return eventCount;
    }

    public void setEventCount(Integer eventCount) {
	this.eventCount = eventCount;
    }

    public String getEventTypes() {
	return eventTypes;
    }

    public void addToPath(String eventType) {
	if (this.eventTypes == null)
	    this.eventTypes = eventType;
	else
	    this.eventTypes += "," + eventType;
    }
}
