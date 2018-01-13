puts 'IMAP duplicate email cleaner'
puts 'Made by: Rob Fors'
puts
puts 'This script will loggin to your IMAP server and look though all email messages to find duplicates.'
puts
puts "The script will require that an empty mailbox called 'duplicates' exists."
puts "It will first load all the emails from each mailbox, then compare them to find duplicates."
puts "An email will be considered to be a duplicate if it shares the same: "
puts "  Date, Subject, From, Sender, Reply_to, To, CC, BCC, In_reply_to and text body."
puts "One of the duplicate emails will then be moved to the 'duplicates' mailbox."
puts "Tip: If one of the duplicate emails are in a mailbox called 'temporary' it is guaranteed to be"
puts "  the one that is moved. Useful if the other emails are orginized in folders and you dont want"
puts "  them to be moved."
puts "Note: The name 'folder' is officaly called 'mailbox' in IMAP terminology."
puts "Warning: Do not modify any emails or folders with another email client when running this script!"
puts "  It should be safe to leave another client open to monitor the progress."
puts

require 'pry'
require 'highline/import'

require_relative "lib/email.rb"

class DuplicateEmailRemover

  def initialize(host = nil, port = nil, use_encryption = nil, username = nil, password = nil)
    host ||= ask("Server Hostname:  ") { |x| x.echo = true }
    port ||= ask("Port (143/993/other):  ") { |x| x.echo = true }.to_i
    use_encryption ||= ask("Encryption (yes/no):  ") { |x| x.echo = true }.to_bool
    username ||= ask("Username:  ") { |x| x.echo = true }
    password ||= ask("Password:  ") { |x| x.echo = "*" }
    @server = Email::Server.connect(host, port, use_encryption, username, password)
    puts 'Connected to server.'
    puts 'Successfully logged in.'
  end
  
  def run
    puts 'Fetching Mailbox List...'
    mailboxes = @server.mailboxes
    puts 'Done.'
    
    @duplicates_mailbox = mailboxes.find { |mailbox| mailbox.name == 'duplicates' }
    unless @duplicates_mailbox && @duplicates_mailbox.messages.reject(&:deleted?).empty?
      puts "The server must have an empty mailbox called 'duplicates' to run this script." 
      #@server.disconnect
      return
    end
    
    puts "Found the 'duplicates' mailbox." 
    puts 'Duplicate emails will be moved to this mailbox.'
    mailboxes.delete(@duplicates_mailbox)
    
    #search each mailbox for messages
    puts 'Loading emails...'
    messages = mailboxes.map(&:messages).flatten
    puts 'Finished'
    
    messages.reject!(&:deleted?)
    
    @duplicates_found = 0
    
    puts
    puts 'Now comparing emails...'
    puts '--------------------------------------------------------------------'
    
    binding.pry
    
    messages.group_by(&:date).each do |date, messages|
      next unless messages.length > 1
      compare(messages)
    end
    
    puts "Finished!  #{@duplicates_found} duplicates found."
  end
  
  def duplicate?(message1, message2)
    message1.date == message2.date &&
    message1.subject == message2.subject &&
    message1.sender == message2.sender &&
    message1.reply_to == message2.reply_to &&
    message1.to == message2.to &&
    message1.cc == message2.cc &&
    message1.bcc == message2.bcc &&
    message1.in_reply_to == message2.in_reply_to &&
    message1.body_text.gsub(/\r|\n/,"") == message2.body_text.gsub(/\r|\n/,"") #remove all newline and carriage return characters (regardless of order), some email clients add/remove these to/from emails, and not only at the end
  end
  
  def compare(messages)
    messages.combination(2) do |two_messages|
    
      message1, message2 = two_messages
      
      print '.'
      
      next if message1.deleted? || message2.deleted?
      next if message1 == message2
      
      next unless duplicate?(message1, message2)
      
      # now assuming duplicate
      
      puts
      puts "Duplicate ##{@duplicates_found}:"
      puts "  Subject: #{message1.subject}"
      puts "  Date: #{message1.date}" if message1.date
      puts "  From: #{message1.from.first['name']} #{message1.from.first['mailbox']}@#{message1.from.first['host']}..." if message1.from.any?
      puts "  locations:"
      puts "    mailbox: #{message1.mailbox.name}, UID: #{message1.uid}"
      puts "    mailbox: #{message2.mailbox.name}, UID: #{message2.uid}"
      puts "--------------------------------------------------------------------"
      
      # move message
      if message1.mailbox.name == 'temporary'
        message1.move_to(@duplicates_mailbox)
      else
        message2.move_to(@duplicates_mailbox)
      end
      
      @duplicates_found += 1
      
      sleep 1
      
    end
  end
  
  def disconnect
    @server.disconnect
    puts 'Disconnected from server.' 
  end
  
  def to_bool(string)
    case string
    when /(true|t|yes|y|1)$/i
      true
    when /(false|f|no|n|0)$/i
      false
    else
      raise "can not convert string '#{string}' into boolean"
    end
  end
end
  

duplicate_email_remover = DuplicateEmailRemover.new('robfors.com', 993, true, 'rob')
duplicate_email_remover.run

