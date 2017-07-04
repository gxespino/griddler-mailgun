require 'spec_helper'

describe Griddler::Mailgun::Adapter do
  it 'registers itself with griddler' do
    expect(Griddler.adapter_registry[:mailgun]).to eq Griddler::Mailgun::Adapter
  end
end

describe Griddler::Mailgun::Adapter, '.normalize_params' do
  it 'works with Griddler::Email' do
    normalized_params = Griddler::Mailgun::Adapter.normalize_params(default_params)
    griddler_email = Griddler::Email.new(normalized_params)
    expect(griddler_email.class).to eq Griddler::Email
  end

  it 'falls back to headers for cc' do
    params = default_params.merge(Cc: '')
    normalized_params = Griddler::Mailgun::Adapter.normalize_params(params)
    expect(normalized_params[:cc]).to eq ["Brandon Stark <brandon@example.com>", "Arya Stark <arya@example.com>"]
  end

  it 'passes the received array of files' do
    params = default_params.merge(
      'attachment-count' => 2,
      'attachment-1' => upload_1,
      'attachment-2' => upload_2
    )

    normalized_params = Griddler::Mailgun::Adapter.normalize_params(params)
    expect(normalized_params[:attachments]).to eq [upload_1, upload_2]
  end

  it "receives attachments sent from store action" do
    params = default_params.merge(
      "attachments" => [{ url: "sample.url", name: "sample name" },
                        { url: "sample2.url", name: "sample name 2" }]
    )
    normalized_params = Griddler::Mailgun::Adapter.normalize_params(params)
    expect(normalized_params[:attachments].length).to eq 2
  end

  it 'has no attachments' do
    normalized_params = Griddler::Mailgun::Adapter.normalize_params(default_params)
    expect(normalized_params[:attachments]).to be_empty
  end

  it 'gets sender from headers' do
    params = default_params.merge(From: '')
    normalized_params = Griddler::Mailgun::Adapter.normalize_params(params)
    expect(normalized_params[:from]).to eq "Jon Snow <jon@example.com>"
  end

  it 'falls back to sender without headers or From' do
    params = default_params.merge(From: '', 'message-headers' => '{}')
    normalized_params = Griddler::Mailgun::Adapter.normalize_params(params)
    expect(normalized_params[:from]).to eq "jon@example.com"
  end

  it 'gets full address from headers' do
    params = default_params.merge(To: '')
    normalized_params = Griddler::Mailgun::Adapter.normalize_params(params)
    expect(normalized_params[:to]).to eq ["John Doe <johndoe@example.com>", "Jane Doe <janedoe@example.com>"]
  end

  it 'handles multiple To addresses' do
    params = default_params.merge(
      To: 'Alice Cooper <alice@example.org>, John Doe <john@example.com>'
    )
    normalized_params = Griddler::Mailgun::Adapter.normalize_params(params)
    expect(normalized_params[:to]).to eq [
      'Alice Cooper <alice@example.org>',
      'John Doe <john@example.com>'
    ]
  end

  it 'handles missing params' do
    normalized_params = Griddler::Mailgun::Adapter.normalize_params(short_params)
    expect(normalized_params[:to]).to eq ['johndoe@example.com']
  end

  it 'handles message-headers' do
    params = default_params.merge(
      'message-headers' => '[["NotCc", "emily@example.mailgun.org"], ["Reply-To", "mail2@example.mailgun.org"]]'
    )
    normalized_params = Griddler::Mailgun::Adapter.normalize_params(params)
    email = Griddler::Email.new(normalized_params)
    expect(email.headers["Reply-To"]).to eq "mail2@example.mailgun.org"
  end

  it 'adds Bcc when it exists' do
    params = default_params.merge('Bcc' => 'bcc@example.com')
    normalized_params = Griddler::Mailgun::Adapter.normalize_params(params)
    expect(normalized_params[:bcc]).to eq ['bcc@example.com']
  end

  it 'bcc is empty array when it missing' do
    normalized_params = Griddler::Mailgun::Adapter.normalize_params(default_params)
    expect(normalized_params[:bcc]).to eq []
  end

  it 'it make a call to VendorSpecificNormalizer' do
    expect(VendorSpecific).to receive(:normalize).with(default_params)

    Griddler::Mailgun::Adapter.normalize_params(default_params)
  end

  def upload_1
    @upload_1 ||= ActionDispatch::Http::UploadedFile.new(
      filename: 'photo1.jpg',
      type: 'image/jpeg',
      tempfile: fixture_file('photo1.jpg')
    )
  end

  def upload_2
    @upload_2 ||= ActionDispatch::Http::UploadedFile.new(
      filename: 'photo2.jpg',
      type: 'image/jpeg',
      tempfile: fixture_file('photo2.jpg')
    )
  end

  def fixture_file(file_name)
    cwd = File.expand_path File.dirname(__FILE__)
    File.new(File.join(cwd, '../../', 'fixtures', file_name))
  end

  def json_headers
    "[
      [\"Subject\", \"multiple recipients and CCs\"],
      [\"From\", \"Jon Snow <jon@example.com>\"],
      [\"To\", \"John Doe <johndoe@example.com>, Jane Doe <janedoe@example.com>\"],
      [\"Cc\", \"Brandon Stark <brandon@example.com>, Arya Stark <arya@example.com>\"]
    ]"
  end

  def short_params
    ActiveSupport::HashWithIndifferentAccess.new(
      {
        "from" => "Jon Snow <jon@example.com>",
        "recipient" => "johndoe@example.com",
        "body-plain" => "hi"
      }
    )
  end

  def default_params
    ActiveSupport::HashWithIndifferentAccess.new(
      {
        "Cc"=>"Brandon Stark <brandon@example.com>, Arya Stark <arya@example.com>",
        "From"=>"Jon Snow <jon@example.com>",
        "Subject"=>"multiple recipients and CCs",
        "To"=>"John Doe <johndoe@example.com>, Jane Doe <janedoe@example.com>",
        "body-html"=>"<div dir=\"ltr\">And attachments. Two of them. An image and a text file.</div>\r\n",
        "body-plain"=>"And attachments. Two of them. An image and a text file.\r\n",
        "from"=>"Jon Snow <jon@example.com>",
        "recipient"=>"johndoe@example.com",
        "sender"=>"jon@example.com",
        "stripped-html"=>"<div dir=\"ltr\">And attachments. Two of them. An image and a text file.</div>\r\n",
        "stripped-signature"=>"",
        "stripped-text"=>"And attachments. Two of them. An image and a text file.",
        "subject"=>"multiple recipients and CCs",
        "timestamp"=>"1402113646",
        "body-calendar" => "BEGIN:VCALENDAR\r\nMETHOD:REQUEST\r\nPRODID:Microsoft Exchange Server 2010\r\nVERSION:2.0\r\nBEGIN:VTIMEZONE\r\nTZID:(UTC-05:00) Eastern Time (US & Canada)\r\nBEGIN:STANDARD\r\nDTSTART:16010101T020000\r\nTZOFFSETFROM:-0400\r\nTZOFFSETTO:-0500\r\nRRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=1SU;BYMONTH=11\r\nEND:STANDARD\r\nBEGIN:DAYLIGHT\r\nDTSTART:16010101T020000\r\nTZOFFSETFROM:-0500\r\nTZOFFSETTO:-0400\r\nRRULE:FREQ=YEARLY;INTERVAL=1;BYDAY=2SU;BYMONTH=3\r\nEND:DAYLIGHT\r\nEND:VTIMEZONE\r\nBEGIN:VEVENT\r\nORGANIZER;CN=Glenn Espinosa:MAILTO:glenn.espinosa@sample.com\r\nATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;CN=Glennpeter\r\n  Espinosa:MAILTO:glenn.espinosa@gmail.com\r\nATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;CN=gx@g\r\n mail.com:MAILTO:gx@gmail.com\r\nATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;CN=ge@o\r\n du.edu:MAILTO:ge@odu.edu\r\nATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;CN=rose.\r\n @gmail.com:MAILTO:rose@gmail.com\r\nATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;CN=track@sample\r\n .com:MAILTO:track@sample.com\r\nDESCRIPTION;LANGUAGE=en-US:\\n\r\nUID:040000008200E00074C5B7101A82E008000000008FCC8C4EEAF4D201000000000000000\r\n 010000000BFC5EC344F3C644EB7D547C356EA6766\r\nSUMMARY;LANGUAGE=en-US:Mid July Design Demo\r\nDTSTART;TZID=\"(UTC-05:00) Eastern Time (US & Canada)\":20170711T150000\r\nDTEND;TZID=\"(UTC-05:00) Eastern Time (US & Canada)\":20170711T173000\r\nCLASS:PUBLIC\r\nPRIORITY:1\r\nDTSTAMP:20170704T173824Z\r\nTRANSP:OPAQUE\r\nSTATUS:REQUEST\r\nSEQUENCE:1\r\nLOCATION;LANGUAGE=en-US:Main Conference Room\r\nX-MICROSOFT-CDO-APPT-SEQUENCE:1\r\nX-MICROSOFT-CDO-OWNERAPPTID:2115445135\r\nX-MICROSOFT-CDO-BUSYSTATUS:FREE\r\nX-MICROSOFT-CDO-INTENDEDSTATUS:FREE\r\nX-MICROSOFT-CDO-ALLDAYEVENT:FALSE\r\nX-MICROSOFT-CDO-IMPORTANCE:2\r\nX-MICROSOFT-CDO-INSTTYPE:0\r\nX-MICROSOFT-DISALLOW-COUNTER:FALSE\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n",
        "message-headers"=>json_headers
      }
    )
  end
end
