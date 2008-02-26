# Provide tasks to load and delete sample user data.
require 'active_record'
require 'active_record/fixtures'

DATA_DIRECTORY = File.join(RAILS_ROOT, "lib", "tasks", "sample_data")

namespace :db do
  namespace :sample_data do 
  
    desc "Load sample data"
    task :load => :environment do |t|
      @lipsum = File.open(File.join(DATA_DIRECTORY, "lipsum.txt")).read
      create_people
      make_messages(@lipsum)
      make_forum_posts
    end
      
    desc "Remove sample data" 
    task :remove => :environment do |t|
      Rake::Task["db:migrate:reset"].invoke
      system("rm -rf public/images/photos/*")
    end
    
    desc "Reload sample data"
    task :reload => :environment do |t|
      # Blow away the Ferret index.
      system("rm -rf index/")
      Rake::Task["db:migrate:reset"].invoke
      Rake::Task["db:sample_data:load"].invoke
    end
  end
end

def create_people
  [%w(female F), %w(male M)].each do |pair|
    filename = File.join(DATA_DIRECTORY, "#{pair[0]}_names.txt")
    names = File.open(filename).readlines
    password = "foobar"
    photos = Dir.glob("lib/tasks/sample_data/#{pair[0]}_photos/*.jpg").shuffle
    names.each_with_index do |name, i|
      name.strip!
      person = Person.create!(:email => "#{name.downcase}@michaelhartl.com",
                              :password => password, 
                              :password_confirmation => password,
                              :name => name,
                              :description => @lipsum)
      Photo.create!(:uploaded_data => uploaded_file(photos[i], 'image/jpg'),
                    :person => person, :primary => true)
    end
  end
end

def make_messages(text)
  michael = Person.find_by_email("michael@michaelhartl.com")
  senders = Person.find(:all, :limit => 10)
  senders.each do |sender|
    Message.create!(:content => text, :sender => michael,
                    :recipient => sender, :skip_send_mail => true)
    Message.create!(:content => text, :sender => sender,
                    :recipient => michael, :skip_send_mail => true)
  end
end

def make_forum_posts
  forum = Forum.find(1)
  people = Person.find(:all)
  %w[foo bar baz].each do |name|
    topic = forum.topics.create(:name => name, :person => people.pick)
    10.times do
      topic.posts.create(:body => @lipsum, :person => people.pick)
    end
  end
end

def uploaded_file(filename, content_type)
  t = Tempfile.new(filename.split('/').last)
  t.binmode
  path = File.join(RAILS_ROOT, filename)
  FileUtils.copy_file(path, t.path)
  (class << t; self; end).class_eval do
    alias local_path path
    define_method(:original_filename) {filename}
    define_method(:content_type) {content_type}
  end
  return t
end