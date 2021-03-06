#
# Author:: Justin Schuhmann (<jmschu02@gmail.com>)
# Cookbook Name:: iis
# Provider:: site
#
# Copyright:: Justin Schuhmann
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/mixin/shell_out'
require 'rexml/document'

include Chef::Mixin::ShellOut
include Opscode::IIS::Helper
include Chef::Util::PathHelper
include REXML

action :add do
  unless @current_resource.exists
    cmd = "#{appcmd} add vdir /app.name:\"#{application_name}\""
    cmd << " /path:\"#{@new_resource.path}\""
    cmd << " /physicalPath:\"#{cleanpath(@new_resource.physical_path)}\""
    cmd << " /userName:\"#{@new_resource.username}\"" if @new_resource.username
    cmd << " /password:\"#{@new_resource.password}\"" if @new_resource.password
    cmd << " /logonMethod:#{@new_resource.logon_method.to_s}" if @new_resource.logon_method
    cmd << " /allowSubDirConfig:#{@new_resource.allow_sub_dir_config}" if @new_resource.allow_sub_dir_config
    
    Chef::Log.info(cmd)
    shell_out!(cmd, {:returns => [0,42]})

    @new_resource.updated_by_last_action(true)
    Chef::Log.info("#{@new_resource} added new virtual directory to application: '#{application_name}'")
  else
    Chef::Log.debug("#{@new_resource} virtual directory already exists - nothing to do")
  end
end

action :config do
  was_updated = false
  cmd_current_values = "#{appcmd} list vdir \"#{application_identifier}\" /config:* /xml"
  Chef::Log.debug(cmd_current_values)
  cmd_current_values = shell_out!(cmd_current_values)
  if cmd_current_values.stderr.empty?
    xml = cmd_current_values.stdout
    doc = Document.new(xml)
    physical_path = is_new_or_empty_value?(doc.root, "VDIR/@physicalPath", @new_resource.physical_path.to_s)
    user_name = is_new_or_empty_value?(doc.root, "VDIR/virtualDirectory/@userName", @new_resource.username.to_s)
    password = is_new_or_empty_value?(doc.root, "VDIR/virtualDirectory/@password", @new_resource.password.to_s)
    logon_method = is_new_or_empty_value?(doc.root, "VDIR/virtualDirectory/@logonMethod", @new_resource.logon_method.to_s)
    allow_sub_dir_config = is_new_or_empty_value?(doc.root, "VDIR/virtualDirectory/@allowSubDirConfig", @new_resource.allow_sub_dir_config.to_s)

    if @new_resource.physical_path && physical_path?
      was_updated = true
      cmd = "#{appcmd} set vdir \"#{application_identifier}\" /physicalPath:\"#{@new_resource.physical_path}\""
      Chef::Log.debug(cmd)
      shell_out!(cmd)
    end

    if @new_resource.username && userName?
      was_updated = true
      cmd = "#{appcmd} set vdir \"#{application_identifier}\" /userName:\"#{@new_resource.username}\""
      Chef::Log.debug(cmd)
      shell_out!(cmd)
    end

    if @new_resource.password && password?
      was_updated = true
      cmd = "#{appcmd} set vdir \"#{application_identifier}\" /password:\"#{@new_resource.password}\""
      Chef::Log.debug(cmd)
      shell_out!(cmd)
    end

    if @new_resource.logon_method && logonMethod?
      was_updated = true
      cmd = "#{appcmd} set vdir \"#{application_identifier}\" /logonMethod:#{@new_resource.logon_method.to_s}"
      Chef::Log.debug(cmd)
      shell_out!(cmd)
    end

    if @new_resource.allow_sub_dir_config && allow_sub_dir_config?
      was_updated = true
      cmd = "#{appcmd} set vdir \"#{application_identifier}\" /allowSubDirConfig:#{@new_resource.allow_sub_dir_config}"
      Chef::Log.debug(cmd)
      shell_out!(cmd)
    end

    if was_updated?
      @new_resource.updated_by_last_action(true)
      Chef::Log.info("#{@new_resource} configured virtual directory to application: '#{application_name}'")
    else
      Chef::Log.debug("#{@new_resource} virtual directory - nothing to do")
    end
  else
    log "Failed to run iis_vdir action :config, #{cmd_current_values.stderr}" do
      level :warn
    end
  end
end

action :delete do
  if @current_resource.exists
    shell_out!("#{appcmd} delete vdir \"#{application_identifier}\"", {:returns => [0,42]})
    @new_resource.updated_by_last_action(true)
    Chef::Log.info("#{@new_resource} deleted")
  else
    Chef::Log.debug("#{@new_resource} virtual directory does not exist - nothing to do")
  end
end

def load_current_resource
  @current_resource = Chef::Resource::IisVdir.new(@new_resource.name)
  @current_resource.application_name(application_name)
  @current_resource.path(@new_resource.path)
  @current_resource.physical_path(@new_resource.physical_path)

  cmd = shell_out("#{ appcmd } list vdir #{ application_identifier }")
  Chef::Log.debug("#{ @new_resource } list vdir command output: #{ cmd.stdout }")

  if cmd.stderr.empty?
    result = cmd.stdout.match(/^VDIR\s\"#{Regexp.escape(application_identifier) }\"/)

    Chef::Log.debug("#{ @new_resource } current_resource match output: #{ result }")
    if result
      @current_resource.exists = true
    else
      @current_resource.exists = false
    end
  else
    log "Failed to run iis_vdir action :load_current_resource, #{cmd_current_values.stderr}" do
      level :warn
    end
  end
end

private
  def application_identifier
    @new_resource.application_name.chomp('/') + @new_resource.path
  end

  def application_name
    if !@new_resource.application_name.end_with? "/"
      @new_resource.application_name = "#{@new_resource.application_name}/"
    end
  end
