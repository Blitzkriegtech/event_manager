# frozen_string_literal: true
require 'date'
require 'time'
require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
# Main file
# Use a csv parser

def get_hour(reg_date_time)
  DateTime.strptime(reg_date_time, '%m/%d/%Y %H:%M').hour
end

def get_day(reg_date_time)
  Date::DAYNAMES[DateTime.strptime(reg_date_time, '%m/%d/%Y %H:%M').wday] # use built in ruby constants to get the name of the day instead of  an index number 
end

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_numbers(phone_numbers)
  cleaned_number = phone_numbers.gsub(/\D/, '') # Remove all non-digit characters
  
  case cleaned_number.length
  when 10
    { number: cleaned_number, valid: true}
  when 11
    cleaned_number[0] == '1' ? { number: cleaned_number[1..-1], valid: true } : { number: nil, valid: false, error: 'Invalid phone number: must start with 1 if 11 digits.' }
  else
    { number: nil, valid: false, error: 'Invalid phone number: must be 10 or 11 digits.' }
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('config/secret.key').strip

  begin
  civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue
    'You can find your representative by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"

  File.open(filename,'w') do |file|
    file.puts form_letter
  end
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv', 
headers: true,
header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

# initialize an empty array for hours and days
hours = [] 
days = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  reg_hour = get_hour(row[:regdate])
  reg_day = get_day(row[:regdate])
  zipcode = clean_zipcode(row[:zipcode])
  phone_numbers = clean_phone_numbers(row[:homephone])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
  puts "Name: #{name} --> Phone number: #{phone_numbers}"

  hours << reg_hour # append the hours of registration when iterations are done
  days << reg_day # append the days of registration when iterations are done
end

def peak_registration_hours(hours)
frequency = Hash.new(0)
hours.each { |hours| frequency[hours] += 1 }
max_frequency = frequency.values.max
peak_hours = frequency.select { |hour, count| count == max_frequency }.keys
peak_hours
end

def peak_registration_days(days)
  frequency = Hash.new(0)
  days.each { |days| frequency[days] +=1 }
  max_frequency = frequency.values.max
  peak_days = frequency.select { |days, count| count == max_frequency }.keys
  peak_days
end

puts "\nPeak registration hour(s): #{peak_registration_hours(hours)}"
puts "\nPeak registration day(s): #{peak_registration_days(days)}}"