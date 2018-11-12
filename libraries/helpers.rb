#
# Cookbook:: logstash_lwrp
# Module:: Helpers
#
# Copyright:: 2018, Mihai Petracovici
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

module LogstashLWRP
  module Helpers
    def logstash_home
      "/opt/logstash_#{new_resource.instance}"
    end

    def logstash_user
      find_resource(:logstash_install, new_resource.instance).ls_user
    end

    def logstash_group
      find_resource(:logstash_install, new_resource.instance).ls_group
    end
  end
end
