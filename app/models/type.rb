#-- encoding: UTF-8
#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2013 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

class Type < ActiveRecord::Base

  extend Pagination::Model

  include ActiveModel::ForbiddenAttributesProtection

  before_destroy :check_integrity

  has_many :work_packages
  has_many :workflows, :dependent => :delete_all do
    def copy(source_type)
      Workflow.copy(source_type, nil, proxy_association.owner, nil)
    end
  end

  has_and_belongs_to_many :projects

  has_and_belongs_to_many :custom_fields,
                          :class_name => 'WorkPackageCustomField',
                          :join_table => "#{table_name_prefix}custom_fields_types#{table_name_suffix}",
                          :association_foreign_key => 'custom_field_id'

  belongs_to :color, :class_name  => 'PlanningElementTypeColor',
                     :foreign_key => 'color_id'

  acts_as_list

  validates_presence_of   :name
  validates_uniqueness_of :name
  validates_length_of     :name,
                          :maximum => 255,
                          :unless => lambda { |e| e.name.blank? }

  validates_inclusion_of :in_aggregation, :is_default, :is_milestone, :in => [true, false]

  default_scope :order => 'position ASC'

  scope :like, lambda { |q|
    s = "%#{q.to_s.strip.downcase}%"
    { :conditions => ["LOWER(name) LIKE :s", {:s => s}],
    :order => "name" }
  }

  scope :without_standard, conditions: { is_standard: false },
                           order: :position

  def to_s; name end

  def <=>(type)
    name <=> type.name
  end

  def self.all
    find(:all, :order => 'position')
  end

  # Returns an array of IssueStatus that are used
  # in the type's workflows
  def issue_statuses
    if @issue_statuses
      return @issue_statuses
    elsif new_record?
      return []
    end

    ids = Workflow.
            connection.select_rows("SELECT DISTINCT old_status_id, new_status_id FROM #{Workflow.table_name} WHERE type_id = #{id}").
            flatten.
            uniq

    @issue_statuses = IssueStatus.find_all_by_id(ids).sort
  end

  def self.search_scope(query)
    like(query)
  end

  def enabled_in?(object)
    object.types.include?(self)
  end

  def available_colors
    PlanningElementTypeColor.all
  end

private
  def check_integrity
    raise "Can't delete type" if WorkPackage.find(:first, :conditions => ["type_id=?", self.id])
  end
end
