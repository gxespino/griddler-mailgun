class VendorSpecific
  attr_reader :params

  def self.normalize(params)
    new(params).normalize
  end

  def initialize(params)
    @params = params
  end

  def normalize
    return {} if params["body-calendar"].nil?

    str      = params["body-calendar"]
    vformat  = VFormat.decode_raw(str).first
    vevent   = vformat.VEVENT
    summary  = vevent.SUMMARY.value
    status   = vevent.STATUS.value
    dt_start = vevent.DTSTART.value
    dt_end   = vevent.DTEND.value

    puts '#' * 25
    puts "Meeting: #{summary}"
    puts "  Date: #{dt_start}"
    puts "  Start time: #{Time.zone.parse(dt_start)}"
    puts "  End time: #{Time.zone.parse(dt_end)}"
    puts "  Status: #{status}"
    puts '#' * 25

    {
      meeting_info: {
        name: summary,
        date: Date.parse(dt_start),
        start_time: Time.zone.parse(dt_start),
        end_time: Time.zone.parse(dt_end),
        status: status
      }
    }
  end
end
