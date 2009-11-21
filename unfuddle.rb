def xml_escape(s)
  s.gsub(/[&<>'"]/) do |char|
    case char
    when '&' then '&amp;'
    when '<' then '&lt;'
    when '>' then '&gt;'
    when "'" then '&apos;'
    when '"' then '&quote;'
    end
  end
end

class Unfuddle
  require 'curl'
  require 'active_support'
  attr_reader :username, :object_url

  def initialize(username, password, subdomain, project_id)
    @username                     = username
    @password                     = password
    @subdomain                    = subdomain
    @project_id                   = project_id
    @curl                         = Curl::Easy.new
    @curl.userpwd                 = "#{@username}:#{@password}"
    @object_url                   = ''
  end

  def comment_on_ticket_number(ticket_number, comment)
    ticket_id = ticket_id_from_number ticket_number
    comment_doc = ({:body => xml_escape(comment)}).to_xml(:root => :comment, :skip_instruct => true)
    @curl.url = "http://#{@subdomain}.unfuddle.com/api/v1/projects/#{@project_id}/tickets/#{ticket_id}/comments"
    headers_for_xml
    @curl.http_post comment_doc
    @object_url = last_post
  end

  def make_new_ticket(title, body)
    ticket_doc = ({:description => "#{xml_escape(body)}", :summary => "#{xml_escape(title)}", :priority => '3'}).to_xml(:root => :ticket, :skip_instruct => true)
    @curl.url = "http://#{@subdomain}.unfuddle.com/api/v1/projects/#{@project_id}/tickets"
    headers_for_xml
    @curl.http_post ticket_doc
    @object_url = last_post
  end

  def upload(file_name, file_path)
    @curl.url = "#{attachment_url}/upload"
    headers_for_file
    @curl.http_post(Curl::PostField.file(file_name, file_path))
    key = Hash.from_xml(@curl.body_str)['upload']['key']
    @curl.url = attachment_url
    attachment_doc = ({:filename => xml_escape(file_name), :upload => { :key => key }}).to_xml(:root => :attachment, :skip_instruct => true)
    headers_for_xml
    @curl.http_post attachment_doc
  end

  def ticket_number_from_id(id)
    @curl.url = "http://#{@subdomain}.unfuddle.com/api/v1/projects/#{@project_id}/tickets/#{id}"
    @curl.http_get
    Hash.from_xml(@curl.body_str)['ticket']['number']
  end

  private
  def attachment_url
    "#{@object_url.sub(/com\/projects/, 'com/api/v1/projects')}/attachments"
  end

  def headers_for_xml
    @curl.headers['Content-type'] = 'application/xml'
    @curl.headers['Accept']       = 'application/xml'
    @curl.multipart_form_post = false
  end

  def headers_for_file
    @curl.headers = {}
    @curl.multipart_form_post = true
  end

  def last_post
    @curl.response_code == 201 and @curl.header_str[/Location: (\S+)/].split.last
  end

  def ticket_id_from_number(number)
    @curl.url = "http://#{@subdomain}.unfuddle.com/api/v1/projects/#{@project_id}/tickets/by_number/#{number}"
    @curl.http_get
    Hash.from_xml(@curl.body_str)['ticket']['id']
  end
end
