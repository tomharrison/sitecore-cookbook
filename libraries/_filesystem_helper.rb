#
# Cookbook Name:: sitecore
# Library:: _filesystem_helper
#
# Copyright 2014, Huge, Inc.
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

include Windows::Helper

#
# Top-level module containing logic for working with Sitecore.
#
module Sitecore
  DEFAULT_UNZIP_OPTIONS = { overwrite: false }

  #
  # Utilities for working with the file system.
  #
  module FilesystemHelper
    include Chef::Mixin::PowershellOut

    #
    # Force a path to have a drive letter, and use backslashes as separators.
    #
    def ps_safe_path(path, drive = 'c')
      if path
        path = win_friendly_path(path)
        path = "#{drive}:#{path}" if path !~ /^[A-Za-z]:/
      end
      path
    end

    #
    # Get a file from either a local path or a remote location, depending on
    # whether the given source string looks like a URL or a file path. This
    # method has the same logic as Windows::Helper::cached_file except it does
    # not cache the end result and therefore can be used multiple times.
    #
    def fetch_file(source, checksum = nil, windows_path = true)
      if source =~ ::URI::ABS_URI && %w(ftp http https).include?(URI.parse(source).scheme)
        uri = ::URI.parse(source)
        cache_file_path = ::File.join(Chef::Config[:file_cache_path],
                                      ::File.basename(::URI.unescape(uri.path)))
        Chef::Log.debug("Downloading file #{source} at #{cache_file_path}")
        r = Chef::Resource::RemoteFile.new(cache_file_path, run_context)
        r.source(source)
        r.backup(false)
        r.checksum(checksum) if checksum
        r.run_action(:create)
      else
        cache_file_path = source
      end

      windows_path ? win_friendly_path(cache_file_path) : cache_file_path
    end

    #
    # Expand the given zip file to the given destination directory. Overwrite
    # any existing files if the overwrite flag is true.
    #
    def unzip(zip, dest, options = nil)
      zip = ps_safe_path(zip)
      dest = ps_safe_path(dest).chomp('/').chomp('\\')
      options = {} unless options.is_a?(Hash)
      settings = Sitecore::DEFAULT_UNZIP_OPTIONS.merge(options)

      unzip = <<-EOH
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = Get-Item('#{zip}')
        $dest = Get-Item('#{dest}')
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
      EOH

      if settings[:overwrite] != true
        unzip = <<-EOH
          if (!(Test-Path '#{dest}\\*'))
          {
            #{unzip}
          }
        EOH
      end

      powershell_out!(unzip) if ::File.exist?(zip) && ::File.directory?(dest)
    end
  end
end
