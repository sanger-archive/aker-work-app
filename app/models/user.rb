class User < ApplicationRecord
  devise :ldap_authenticatable, :rememberable, :trackable

  def fetch_groups
    # Doing this for now as not actually wanting to look up information from LDAP so stubbing
    return ['pirates']

    name = self.email
    DeviseLdapAuthenticatable::Logger.send("Getting groups for #{name}")
    connection = Devise::LDAP::Adapter.ldap_connect(name)
    filter = Net::LDAP::Filter.eq("member", connection.dn)
    connection.ldap.search(:filter => filter, :base => Rails.application.config.ldap["group_base"]).collect(&:cn).flatten
  end
end
