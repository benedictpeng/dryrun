require 'optparse'
require 'colorize'
require 'tmpdir'
require 'fileutils'
require 'dryrun/github'
require 'dryrun/version'
require 'dryrun/android_project'

module DryRun
  class MainApp
    def initialize(arguments)

      @url = ['-h', '--help', '-v', '--version'].include?(arguments.first) ? nil : arguments.shift
      
      # defaults
      @app_path = nil
      @custom_module = nil
      @flavour = ''
      @tag = nil
      @branch = "master"

      # Parse Options
      arguments.push "-h" unless @url
      create_options_parser(arguments)
    end

    def create_options_parser(args)
      args.options do |opts|
        opts.banner = "Usage: dryrun GIT_URL [OPTIONS]"
        opts.separator  ''
        opts.separator  "Options"

        opts.on('-m MODULE_NAME', '--module MODULE_NAME', 'Custom module to run') do |custom_module|
          @custom_module = custom_module
        end

        opts.on('-b BRANCH_NAME', '--branch BRANCH_NAME', 'Checkout custom branch to run') do |branch|
          @branch = branch
        end

        opts.on('-f', '--flavour FLAVOUR', 'Custom flavour (e.g. dev, qa, prod)') do |flavour|
          @flavour = flavour.capitalize
        end

        opts.on('-p PATH', '--path PATH', 'Custom path to android project') do |app_path|
          @app_path = app_path
        end

        opts.on('-t TAG', '--tag TAG', 'Checkout tag/commit hash to clone (e.g. "v0.4.5", "6f7dd4b")') do |tag|
          @tag = tag
        end

        opts.on('-h', '--help', 'Displays help') do
          puts opts.help
          exit
        end

        opts.on('-v', '--version', 'Displays the version') do
          puts DryRun::VERSION
          exit
        end

        opts.parse!

      end
    end

    def android_home_is_defined
      sdk = `echo $ANDROID_HOME`.gsub("\n",'')
      !sdk.empty?
    end

    def call
      unless android_home_is_defined
        puts "\nWARNING: your #{'$ANDROID_HOME'.yellow} is not defined\n"
        puts "\nhint: in your #{'~/.bashrc'.yellow} or #{'~/.bash_profile'.yellow}  add:\n  #{"export ANDROID_HOME=\"/Users/cesarferreira/Library/Android/sdk/\"".yellow}"
        puts "\nNow type #{'source ~/.bashrc'.yellow}\n\n"
        exit 1
      end

      github = Github.new(@url)

      unless github.is_valid
        puts "#{@url.red} is not a valid git @url"
        exit 1
      end

      # clone the repository
      repository_path = github.clone(@branch, @tag)

      android_project = AndroidProject.new(repository_path, @app_path, @custom_module, @flavour)

      # is a valid android project?
      unless android_project.is_valid
        puts "#{@url.red} is not a valid android project"
        exit 1
      end

      puts "Using custom app folder: #{@app_path.green}" if @app_path
      puts "Using custom module: #{@custom_module.green}" if @custom_module

      # clean and install the apk
      android_project.install

      puts "\n> If you want to remove the app you just installed, execute:\n#{android_project.get_uninstall_command.red}\n\n"
    end
  end
end
