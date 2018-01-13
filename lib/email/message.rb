module Email
  class Message
  
    attr_reader :mailbox, :uid
  
    def initialize(mailbox, uid, envelope = nil, flags = nil)
      @mailbox = mailbox
      @imap = @mailbox.imap
      @uid = uid
      @envelope = envelope || get_envelope
      @flags = flags || get_flags
      @deleted = @flags.include?(:Deleted)
    end
    
    def expired?
      @mailbox.expired?
    end
    
    def deleted?
      @deleted
    end
    
    def delete
      raise if deleted?
      @mailbox.select
      @imap.uid_store(@uid, "+FLAGS", [:Deleted]) # mark deleted
      @deleted = true
      nil
    end
    
    def date
      if @envelope['date']
        DateTime.parse(@envelope['date']) rescue @envelope['date']
      else
        nil
      end
    end
    
    def subject
      @envelope['subject']
    end
    
    def from
      @envelope['from'] || []
    end
    
    def sender
      @envelope['sender'] || []
    end
    
    def reply_to
      @envelope['reply_to'] || []
    end
    
    def to
      @envelope['to'] || []
    end
    
    def cc
      @envelope['cc'] || []
    end
    
    def bcc
      @envelope['bcc'] || []
    end
    
    def in_reply_to
      @envelope['in_reply_to'] || []
    end
    
    def body_text
      @mailbox.select
      @imap.uid_fetch(@uid, "BODY[TEXT]")[0].attr["BODY[TEXT]"]
    end
    
    def copy_to(mailbox)
      @mailbox.select
      response = @imap.uid_copy(@uid, mailbox.name)
      new_uid = response.data.code.data.split(' ')[2].to_i
      mailbox.select # check UIDVALIDITY
      Message.new(mailbox, new_uid)
    end
    
    def move_to(mailbox)
      raise if deleted?
      new_message = copy_to(mailbox)
      delete
      new_message
    end
    
    def ==(other_message)
      @mailbox == other_message.mailbox &&
      @uid == other_message.uid
    end
    
    private
    
    def get_envelope
      @mailbox.select
      @envelope = @imap.uid_fetch(@uid, "ENVELOPE").first.attr["ENVELOPE"]
    end
    
    def get_flags
      @mailbox.select
      @imap.uid_fetch(@uid, "FLAGS").first.attr["FLAGS"]
    end
    
  end
end
