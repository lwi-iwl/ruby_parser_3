require 'mechanize'
require 'json'
require 'ox'

class KiloutouParser
  def generate_xml(path)
    doc = Ox::Document.new(:version => '1.0')
    jobs = get_jobs
    jobs_count = jobs.nodes.count
    source = Ox::Element.new('source')
    source << (Ox::Element.new('jobs_count') << jobs_count.to_s)
    source << (Ox::Element.new('generation_time') << Time.now.utc.strftime('%m/%d/%Y %H:%M %p'))
    source << jobs
    doc << source
    xml = Ox.dump(doc)
    File.write(path + '//file.xml', xml, mode: 'w')
  end

  private

  def get_jobs
    jobs = Ox::Element.new('jobs')
    @mechanize = Mechanize.new
    get_links.each do |link|
      jobs << get_job(link)
    end
    jobs
  end


  def get_job(link)
    parameters = get_parameters(link)
    job = Ox::Element.new('job')
    parameters.keys.each do |key|
      job << (Ox::Element.new(key) << parameters[key])
    end
    job
  end

  def get_parameters(link)
    page = @mechanize.get(link)
    if link.split('/')[2] == "kiloutou.gestmax.fr"
      get_kilotou_parameters(page, link)
    else
      get_canditates_parameters(page, link)
    end
  end

  def get_kilotou_parameters(page, link)
    company_description = ''
    page.at_xpath("//div[@class='vacancy-presentation']").search("p").each do |part|
      company_description += part.to_s
    end
    Hash[
      title: page.title,
      url: link,
      job_reference: link.split('/')[3],
      city: page.at_xpath("//div[@class='title-city']").text,
      location: page.at_xpath("//div[@class='title-city']").text,
      body: company_description +
        page.at_xpath("//div[@class='vacancy-text']").text
    ]
  end

  def get_canditates_parameters(page, link)
    description = ''
    page.xpath("//div[@class='text']").each do |part|
      puts part.search("div").text
      description += part.text
    end
    Hash[
      title: page.title,
      url: link,
      job_reference: link.split('/')[4],
      city: page.at_xpath("//div[@class='infos']").search("div")[1].text.split('-')[1],
      location: page.at_xpath("//div[@class='infos']").search("div")[1].text.split('-')[1],
      body: description
    ]
  end

  def get_links
    links = Array.new
    page = @mechanize.get("https://kiloutou.gestmax.fr/search/faceted/searchAction/all/field/vacsearchfront_localisation/value/all/page/1")
    pages_count = page.at_xpath("//*[@class='pagination']").search("a")[-2].text.to_i
    links = links.concat(get_page_links(page))
    (2..pages_count).each do |page_number|
      page = @mechanize.get("https://kiloutou.gestmax.fr/search/faceted/searchAction/all/field/vacsearchfront_localisation/value/all/page/#{page_number}")
      links = links.concat(get_page_links(page))
    end
    links
  end

  def get_page_links(page)
    links = Array.new
    page.at_xpath("//div[@class='list-group']").search("a").each do |node|
      links.push(node.attr('href').to_s)
    end
    links
  end
end