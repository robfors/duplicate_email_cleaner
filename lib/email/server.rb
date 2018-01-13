module Email
  class Server
  
    attr_reader :host, :port, :use_encryption, :username, :password, :imap
    
    def self.connect(*args)
      new(*args)
    end
    
    def initialize(host, port, use_encryption, username, password)
      connect(host, port, use_encryption)
      login(username, password)
      @connected = true
    end
    
    def disconnect
      @imap.disconnect
      @connected = false
      nil
    end
    
    def connected?
      @connected
    end
    
    def expired?
      !connected?
    end
    
    def mailboxes
      raise 'Server object has expired.' if expired?
      mailbox_names = @imap.list("","*").map { |mailbox_list| mailbox_list['name'] }.sort
      mailbox_names.map { |mailbox_name| Mailbox.new(self, mailbox_name) }
    end
    
    def ==(other_server)
      host == other_server.host &&
      port == other_server.port &&
      username == other_server.username &&
      password == other_server.password
    end
    
    private
    
    def connect(host, port, use_encryption)
      @imap = Net::IMAP.new(host, port, use_encryption)
      #to ignore ssl errors
      #@imap = Net::IMAP.new(host, port, use_encryption, nil, false)
      nil
    end
    
    def login(username, password)
      @imap.login(username, password)
      nil
    end
    
  end
end
