require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'
peak_hours = {}
peak_wday = {}

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phonenumber)
  phonenumber.gsub!(/[^0-9]/, '') 
    if phonenumber.length < 10 || phonenumber.length > 11 || (phonenumber.length == 11 && phonenumber[0] != "1")
      "Bad number"
    elsif phonenumber.length == 10
      phonenumber
    elsif phonenumber.length == 11 && phonenumber[0] == "1"
      phonenumber[1..10]
    end
end

def find_peak_hours(times, peak_hours)
  datetime = DateTime.strptime(times, "%m/%d/%y %H:%M")
  time = datetime.to_time
  hour = time.hour
  peak_hours[hour] ||= 0
  peak_hours[hour] += 1
end

def find_peak_wday(wdays, peak_wday)
  days_of_the_week = Date.strptime(wdays, "%m/%d/%y")
  day_of_the_week = days_of_the_week.wday
  case day_of_the_week
  when 0
    day_of_the_week = "Sunday"
  when 1
    day_of_the_week = "Monday"
  when 2
    day_of_the_week = "Tuesday"
  when 3
    day_of_the_week = "Wednesday"
  when 4
    day_of_the_week = "Thursday"
  when 5
    day_of_the_week = "Friday"
  when 6
    day_of_the_week = "Saturday"
  end

  peak_wday[day_of_the_week] ||= 0
  peak_wday[day_of_the_week] += 1
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]

  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  phonenumber = clean_phone_number(row[:homephone])

  peak_registration_hours = find_peak_hours(row[:regdate], peak_hours)

  peak_reg_wday = find_peak_wday(row[:regdate], peak_wday)

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

end

p peak_wday