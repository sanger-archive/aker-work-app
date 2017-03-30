class User < ApplicationRecord
  devise :ldap_authenticatable, :rememberable, :trackable

  def ldap_before_save
    p '**** Here is the group info: '
    p Devise::LDAP::Adapter.get_groups('uid=cs24,ou=people,dc=sanger,dc=ac,dc=uk')
  end
end
