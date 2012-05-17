#
# Cookbook Name:: repo_git
#
# Copyright RightScale, Inc. All rights reserved.  All access and use subject to the
# RightScale Terms of Service available at http://www.rightscale.com/terms.php and,
# if applicable, other agreements such as a RightScale Master Subscription Agreement.


action :pull do

  capistrano_dir="/home/capistrano_repo"
  ruby_block "Before pull" do
    block do
      Chef::Log.info "check previous repo in case of action change"
      if (::File.exists?("#{new_resource.destination}") == true && ::File.symlink?("#{new_resource.destination}") == true && ::File.exists?("#{capistrano_dir}") == true)
        ::File.rename("#{new_resource.destination}", "#{capistrano_dir}/releases/capistrano_old_"+::Time.now.strftime("%Y%m%d%H%M"))
      end
      # Add ssh key and exec script
      RightScale::Repo::Ssh_key.new.create(new_resource.git_ssh_key)
    end
  end

  # pull repo (if exist)
  ruby_block "Pull existing git repository at #{new_resource.destination}" do
    only_if do ::File.directory?(new_resource.destination) end
    block do
      branch = new_resource.revision

      Dir.chdir new_resource.destination
      Chef::Log.info "  Updating existing git repo at #{new_resource.destination}"
      Chef::Log.info `git pull`
    end
  end

  # Clone repo (if not exist)
  ruby_block "Clone new git repository at #{new_resource.destination}" do
    not_if do ::File.directory?(new_resource.destination) end
    block do
      Chef::Log.info "  Creating new git repo at #{new_resource.destination}"
      Chef::Log.info `git clone #{new_resource.repository} -- #{new_resource.destination}`
      branch = new_resource.revision
      if "#{branch}" != "master"
        dir = "#{new_resource.destination}"
        Dir.chdir(dir) 
        Chef::Log.info `git checkout --track -b #{branch} origin/#{branch}`
      end
    end
  end

  # Delete SSH key & clear GIT_SSH
  ruby_block "After pull" do
    block do
      RightScale::Repo::Ssh_key.new.delete
    end
  end

  Log "  GIT repo pull action - finished successfully!"
end

action :capistrano_pull do

  # Add ssh key and exec script
  ruby_block "Before deploy" do
    block do
       RightScale::Repo::Ssh_key.new.create(new_resource.git_ssh_key)
    end
  end

  log "  Preparing to capistrano deploy action. Setting parameters for the process..."
  destination = new_resource.destination
  repository = new_resource.repository
  revision = new_resource.revision
  app_user = new_resource.app_user
  purge_before_symlink = new_resource.purge_before_symlink
  create_dirs_before_symlink = new_resource.create_dirs_before_symlink
  symlinks = new_resource.symlinks
  scm_provider = new_resource.provider
  environment = new_resource.environment
  log "  Deploying branch: #{revision} of the #{repository} to #{destination}. New owner #{app_user}"
  log "  Deploy provider #{scm_provider}"

  # Applying capistrano style deployment
  capistranize_repo "Source repo" do
    repository                 repository
    revision                   revision
    destination                destination
    app_user                   app_user
    purge_before_symlink       purge_before_symlink
    create_dirs_before_symlink create_dirs_before_symlink
    symlinks                   symlinks
    scm_provider               scm_provider
    environment                environment
  end

  # Delete SSH key & clear GIT_SSH
  ruby_block "Before deploy" do
    block do
      RightScale::Repo::Ssh_key.new.delete
    end
  end

  Log "  Capistrano GIT deployment action - finished successfully!"
end
