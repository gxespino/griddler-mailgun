require 'spec_helper'

describe VendorSpecific, '.normalize_params' do
  before do
    Time.zone = 'EST'
  end

  it 'returns the correct params for an iCalendar string' do
    expected = {
      meeting_info: {
        uid: 'XXXXXX',
        name: 'Mid July Design Demo',
        date: Date.parse('20170711T1500'),
        start_time: Time.zone.parse('20170711T1500'),
        end_time: Time.zone.parse('20170711T1730'),
        status: 'REQUEST'
      }
    }
    normalized_params = VendorSpecific.normalize(default_params)

    expect(normalized_params).to eq expected
  end

  def default_params
    ActiveSupport::HashWithIndifferentAccess.new(
      {
        "body-calendar" => "BEGIN:VCALENDAR\r\nMETHOD:REQUEST\r\nPRODID:Microsoft Exchange Server 2010\r\nVERSION:2.0\r\nBEGIN:VTIMEZONE\r\nTZID:(UTC-05:00) Eastern Time (US & Canada)\r\nBEGIN:STANDARD\r\nDTSTART:16010101T020000\r\nTZOFFSETFROM:-0400\r\nTZOFFSETTO:-0500\r\nRRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=1SU;BYMONTH=11\r\nEND:STANDARD\r\nBEGIN:DAYLIGHT\r\nDTSTART:16010101T020000\r\nTZOFFSETFROM:-0500\r\nTZOFFSETTO:-0400\r\nRRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=2SU;BYMONTH=3\r\nEND:DAYLIGHT\r\nEND:VTIMEZONE\r\nBEGIN:VEVENT\r\nORGANIZER;CN=Glenn Espinosa:MAILTO:glenn.espinosa@sample.com\r\nATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;CN=Glennpeter\r\n  Espinosa:MAILTO:glenn.espinosa@gmail.com\r\nATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;CN=gx@g\r\n mail.com:MAILTO:gx@gmail.com\r\nATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;CN=ge@o\r\n du.edu:MAILTO:ge@odu.edu\r\nATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;CN=rose.\r\n @gmail.com:MAILTO:rose@gmail.com\r\nATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;CN=track@sample\r\n .com:MAILTO:track@sample.com\r\nDESCRIPTION;LANGUAGE=en-US:\\n\r\nUID:XXX\r\n XXX\r\nSUMMARY;LANGUAGE=en-US:Mid July Design Demo\r\nDTSTART;TZID=\"(UTC-05:00) Eastern Time (US & Canada)\":20170711T150000\r\nDTEND;TZID=\"(UTC-05:00) Eastern Time (US & Canada)\":20170711T173000\r\nCLASS:PUBLIC\r\nPRIORITY:1\r\nDTSTAMP:20170704T173824Z\r\nTRANSP:OPAQUE\r\nSTATUS:REQUEST\r\nSEQUENCE:1\r\nLOCATION;LANGUAGE=en-US:Main Conference Room\r\nX-MICROSOFT-CDO-APPT-SEQUENCE:1\r\nX-MICROSOFT-CDO-OWNERAPPTID:2115445135\r\nX-MICROSOFT-CDO-BUSYSTATUS:FREE\r\nX-MICROSOFT-CDO-INTENDEDSTATUS:FREE\r\nX-MICROSOFT-CDO-ALLDAYEVENT:FALSE\r\nX-MICROSOFT-CDO-IMPORTANCE:2\r\nX-MICROSOFT-CDO-INSTTYPE:0\r\nX-MICROSOFT-DISALLOW-COUNTER:FALSE\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n",
      }
    )
  end
end
