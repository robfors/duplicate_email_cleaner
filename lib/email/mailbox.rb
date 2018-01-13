module Email
  class Mailbox
  
    attr_reader :name, :server, :imap
  
    def initialize(server, name)
      @server = server
      @name = name
      @imap = server.imap
      @uid_validity = uid_validity
    end
    
    def expired?
      @server.expired? || @uid_validity != uid_validity
    end
    
    def messages
      select
      return [] if message_count == 0
      @imap.fetch(1..-1, "(UID ENVELOPE FLAGS)").map do |fetch_data|
        Message.new(self, fetch_data.attr["UID"], fetch_data.attr["ENVELOPE"], fetch_data.attr["FLAGS"])
      end
    end
    
    def select
      check_expired
      @imap.select(@name)
      nil
    end
    
    def ==(other_mailbox)
      @name == other_mailbox.name && @server == other_mailbox.server
    end
    
    private
    
    def check_expired
      raise 'object has expired.' if expired?
      nil
    end
    
    def uid_validity
      @server.imap.status(@name, ["UIDVALIDITY"])["UIDVALIDITY"]
    end
    
    def message_count
      @imap.status(@name, ["MESSAGES"])["MESSAGES"]
    end
    
  end
end
