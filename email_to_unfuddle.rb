require 'gmail'
require 'unfuddle'

unfuddle = Unfuddle.new(unfuddle_username, unfuddle_password, unfuddle_subdomain, unfuddle_project_id)
gmail    = Gmail.new(mail_username, mail_password)

gmail.inbox.emails(:unread).map do |email|
  text = email.message.find_parts(:content_type => 'text/plain').map {|part| part.content}.to_s
  case email.message.subject
  when /GS TICKET #(\d+)/i
    ticket_number = Regexp.last_match 1
    unfuddle.comment_on_ticket_number(ticket_number, text) and \
      email.mark(:read) and \
      email.archive!
  when /NEW GS TICKET (.*)/i
    ticket_title = Regexp.last_match 1
    unfuddle.make_new_ticket(ticket_title, text) and \
      email.mark(:read) and \
      email.archive! and \
      ticket_number = unfuddle.ticket_number_from_id(unfuddle.object_url.split('/').last)
    if ticket_number
      response = gmail.new_message
      response.to email.message.from
      response.subject "[GS TICKET ##{ticket_number}] #{ticket_title}"
      plain, html   = response.generate_multipart('text/plain', 'text/html')
      plain.content = "Ticket ##{ticket_number} has been opened in reference to #{ticket_title}"
      html.content  = "<p><a href=#{unfuddle.object_url}>Ticket ##{ticket_number}</a> has been opened in reference to #{ticket_title}</p>"
      gmail.send_email(response)
    end
  else
    puts "<<#{email.message.subject}>> from <<#{email.message.from}>> is not for us"
    next #skip attachment processing
  end
  unless email.message.attachments.empty?
    email.message.save_attachments_to('/tmp')
    email.message.attachments.map {|attachment|
      unfuddle.upload "#{attachment.attachment_filename}", "/tmp/#{attachment.attachment_filename}"
      system "rm /tmp/#{attachment.attachment_filename}"
    }
  end
end
