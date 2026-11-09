class AdminOverview {const AdminOverview({required this.users,required this.roles,required this.permissions});final List<ManagedUser> users;final List<ManagedRole> roles;final List<String> permissions;}
class ManagedUser {const ManagedUser({required this.id,required this.email,required this.fullName,required this.status,required this.roles});final String id,email,fullName,status;final List<String> roles;}
class ManagedRole {const ManagedRole({required this.code,required this.name,required this.permissions});final String code,name;final List<String> permissions;}
class SystemSetting {const SystemSetting({required this.key,required this.value,this.description});final String key;final Object? value;final String? description;}
