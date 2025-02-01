# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
# Main file
# Use a csv parser
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
    'You can find your representativ by visiting www.commoncause.org/take-action/find-elected-officials'
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

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_numbers = clean_phone_numbers(row[:homephone])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id,form_letter)
  # p name
  # p legislators
  puts "Name: #{name} --> Phone number: #{phone_numbers}"
end