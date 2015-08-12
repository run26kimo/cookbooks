include_recipe 'deploy'

node[:deploy].each do |application, deploy|
  if deploy[:application_type] != 'nodejs'
    Chef::Log.debug("Skipping deploy::nodejs for application #{application} as it is not a node.js app")
    next
  end

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  opsworks_deploy do
    deploy_data deploy
    app application
  end

  %w{webpack pm2}.each do |pkg|
    execute "npm install #{pkg} on gloabl" do
      cwd ::File.join(deploy[:deploy_to], 'current')
      command "npm install -g #{pkg}"
      not_if "which #{pkg}"
    end
  end

  execute 'Build node js' do
    user deploy[:user]
    group deploy[:group]
    cwd ::File.join(deploy[:deploy_to], 'current')
    command '/usr/local/bin/npm run build'
    not_if { ::File.directory?("#{deploy[:deploy_to]}/current/build") }
  end


  # for pm2 
  template "#{deploy[:deploy_to]}/shared/app.json" do
    source 'pm2_app.json.erb'
    owner deploy[:user]
    group deploy[:group]
    mode '0700'
    variables(
      application: application,
      deploy: deploy,
      environment: deploy[:environment_variables]
    )
  end

  opsworks_nodejs do
    deploy_data deploy
    app application
  end

  application_environment_file do
    user deploy[:user]
    group deploy[:group]
    path ::File.join(deploy[:deploy_to], "shared")
    environment_variables deploy[:environment_variables]
  end


  ruby_block "restart node.js application #{application}" do
    block do
      Chef::Log.info("restart node.js via: #{node[:deploy][application][:nodejs][:restart_command]}")
      Chef::Log.info(`#{node[:deploy][application][:nodejs][:restart_command]}`)
      $? == 0
    end
  end
end
