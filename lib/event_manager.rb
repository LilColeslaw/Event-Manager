require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'pry-byebug'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  # first get rid of non-digits (dashes and paretheses etc)
  numbers = (0..9).map(&:to_s)
  phone_number = phone_number.split('').filter { |digit| numbers.include? digit }.join('')
  # check for size
  case phone_number.length
  when 10 then phone_number
  when 11
    if phone_number[0] == '1' # trim the 1 at the beginning if there are 11 digits
      phone_number[1..10]
    else
      'Invalid Number'
    end
  else
    'Invalid Number'
  end
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  stdout = $stdout
  stderr = $stderr
  begin
    $stdout = $stderr = StringIO.new
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    )
    $stdout = stdout
    $stderr = stderr
    legislators.officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  ensure
    $stdout = stdout
    $stderr = stderr
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist? 'output'

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.write form_letter
  end
end

def get_peak_registration_hours(times)
  # get the hours (0 - 23) and count how many for each hour
  times.map { |time| DateTime.strptime(time, '%m/%d/%y %H:%M').hour.to_s << ':00' }.tally
end

def get_peak_registration_days(times)
  times = times.map { |time| Date.strptime(time, '%m/%d/%y') } # puts the times in date format (no hours/minutes)
  times = times.map { |time| time.strftime('%A') }.tally # makes times into strings of weekdays and counts occurences
end

puts 'EventManager initialized.'

template_letter = File.read('form_letter.erb')
erb_template = ERB.new(template_letter)

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)

peak_registration_times = get_peak_registration_hours(contents.map { |row| row[:regdate] })
puts peak_registration_times
contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)
peak_registration_days = get_peak_registration_days(contents.map { |row| row[:regdate] })
puts peak_registration_days
