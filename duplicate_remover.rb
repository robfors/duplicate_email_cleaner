puts 'IMAP duplicate locator'
puts 'Made by: Rob Fors'
puts
puts 'This script will loggin to your IMAP server and look though all email messages to find duplicates.'
puts 'More...(ENTER)'
gets
puts
puts 'After loggin in it will make the folder "duplicates". It will then load the email headers in every email folder and compare every email with every other email header. An email will be considered as a duplicate if both have these same fields:'
puts '  Date, Subject, From, Sender, Reply_to, To, CC, BCC, In_reply_to'
puts 'If this check passes the script will then load and compare the body of both messages.'
puts 'Having passed that the one of the emails will then be moved to the duplicates folder.'
puts
puts '*Tip: If one of the duplicate emails are in a folder called "temp" it is guaranteed to be the one that is moved. Useful if the other emails are orginized in folders and you dont want them to be moved.'
puts
puts 'Warning: Do not modify any emails or folders with another email client when running this script! It should be safe to leave another client open to just monitor the progress.'
puts

#****Progamer Note****
#  The name "folder" is officaly called "mailbox" in IMAP terminology. mailbox is used in the comments.

require 'rubygems'
require 'net/imap'
require 'highline/import'

class String
  def to_bool
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    return false if self == false || self.empty? || self =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
end

server = ''
port = 0
ssl = false

server = ask("Server:  ") { |x| x.echo = true }
port = ask("Port (143/993/other):  ") { |x| x.echo = true }.to_i
ssl = ask("SSL (yes/no):  ") { |x| x.echo = true }.to_bool
imap = Net::IMAP.new('hac5.com', 993, true)

#to ignore ssl errors
#imap = Net::IMAP.new('hac5.com', 993, true, nil, false)

puts 'Connected to server...'

user = ''
password = ''

user = ask("Username:  ") { |x| x.echo = true }
password = ask("Password:  ") { |x| x.echo = "*" }
imap.login(user, password)

puts 'Successfully logged in.'

messages = []

#get array of all mailboxs
puts
puts 'Fetching Mailbox List...'
mailboxList = imap.list("","*").collect{|mailboxObj| mailboxObj['name']}.sort

if mailboxList.include?('duplicates')
  puts 'Server already has the folder "duplicates".' 
  puts 'Duplicate emails will be added to this folder.'
  accepted = ask("Is this OK? (yes/no)") { |x| x.echo = true }.to_bool
  if not accepted
    imap.disconnect()
    exit
  end
  mailboxList.delete_if { |element| true if element == 'duplicates' }
elsif
  imap.create('duplicates')
  puts 'Created folder "duplicates".'
  puts 'Any duplicate emails found will be moved to this folder.'
end

#search each mailbox for all messages
puts
puts 'Loading email headers...'
mailboxList.each do |mailbox|
  imap.select(mailbox)
  messageCount = imap.status(mailbox, ["MESSAGES"])["MESSAGES"]
  puts 'Loading Folder: ' + mailbox + ' (' + messageCount.to_s + ' emails)'
  next if messageCount == 0
  imap.fetch(1..-1, "(UID ENVELOPE FLAGS)").each do |messageObj|
    messages << {'messageArrayNum' => messages.length, 'mailbox' => mailbox, 'uid' => messageObj.attr["UID"] , 'envelope' => messageObj.attr["ENVELOPE"], 'moved' => false, 'deleted' => messageObj.attr["FLAGS"].include?(:Deleted) }
  end
end
puts 'Finished loading email headers.'
puts 'DO NOT MAKE ANY CHANGES UNTILL FINISHED OR FORCED CLOSED.'
#with every message:

duplicatesFound = 0

puts
puts 'Now comparing emails...'
puts '--------------------------------------------------------------------'
messages.each do |message1|
  print '.'
  messages.each do |message2|
    
    #skip comparing the message with itself
    next if message1['mailbox'] == message2['mailbox'] && message1['uid'] == message2['uid']
    #skip already moved messages
    next if message1['moved']
    next if message2['moved']
    #skip already deleted messages
    next if message1['deleted']
    next if message2['deleted']
    
    #look for duplicate headers
    next if message1['envelope']['date'] != message2['envelope']['date']
    next if message1['envelope']['subject'] != message2['envelope']['subject']
    next if message1['envelope']['from'] != message2['envelope']['from']
    next if message1['envelope']['sender'] != message2['envelope']['sender']
    next if message1['envelope']['reply_to'] != message2['envelope']['reply_to']
    next if message1['envelope']['to'] != message2['envelope']['to']
    next if message1['envelope']['cc'] != message2['envelope']['cc']
    next if message1['envelope']['bcc'] != message2['envelope']['bcc']
    next if message1['envelope']['in_reply_to'] != message2['envelope']['in_reply_to']
    
    #compare body
    imap.select(message1['mailbox'])
    body1 = imap.uid_fetch(message1['uid'], "BODY[TEXT]")[0].attr['BODY[TEXT]'].gsub(/\r|\n/,"") #remove all newline and carriage return characters (regardless of order), some email clients add/remove these to/from emails, and not only and the end
    imap.select(message2['mailbox'])
    body2 = imap.uid_fetch(message2['uid'], "BODY[TEXT]")[0].attr['BODY[TEXT]'].gsub(/\r|\n/,"")
    next if body1 != body2
    
    #got this far, now assuming duplicate
    puts 'Found duplicate:'
    puts '     Subject: "' + message1['envelope']['subject'].to_s + '"'
    puts '     Date: "' + message1['envelope']['date'].to_s + '"'
    puts '     From: "' + message1['envelope']['from'][0]['name'].to_s + ' ' + message1['envelope']['from'][0]['mailbox'].to_s + '@' + message1['envelope']['from'][0]['host'].to_s + '...'
    puts 'Folders:'
    puts '     "' + message1['mailbox'] + '" UID: ' + message1['uid'].to_s
    puts '     "' + message2['mailbox'] + '" UID: ' + message2['uid'].to_s
    puts '--------------------------------------------------------------------'
    
    #move message
    if message1['mailbox'][0..4] == 'temp' && message1['mailbox'][0..4] != 'temp'
      messageToMove = message1
    else
      messageToMove = message2
    end
    
    imap.select(messageToMove['mailbox'])
    imap.uid_copy(messageToMove['uid'], 'duplicates')
    imap.uid_store(messageToMove['uid'], "+FLAGS", [:Deleted]) #Mark Deleted
    messages[messageToMove['messageArrayNum']]['moved'] = true
    
    duplicatesFound += 1
  end
end

imap.disconnect()

puts 'Finished!   ' + duplicatesFound.to_s + ' Duplicates found.'
puts 'Disconnected from server.'

#Old Code

#messagesLoaded = 0

  #messageNum = imap.status(mailbox, ["MESSAGES"])["MESSAGES"]
  #messageNum.times do |sequenceNumber|
  #  sequenceNumber += 1
  #  #fetch every message and save to single array
  #  fetchMessage = imap.fetch(sequenceNumber, "(UID ENVELOPE)")[0]
  #  messages << {'mailbox' => mailbox, 'uid' => fetchMessage.attr["UID"] , 'envelope' => fetchMessage.attr["ENVELOPE"]}
  #  puts 'Messages Loaded: ' + messagesLoaded.to_s if ((messagesLoaded += 1) % 50) == 0
  #end
