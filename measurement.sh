#!/usr/bin/env bash

num_cpus=${1:-256}
cc_kbc=${2:-"https://kbs.confidentialfilesystems.com:30443"}
type_cpus=('EPYC-v4')

#console_debugs=('' 'agent.log=debug agent.debug_console agent.debug_console_vport=1026 ')
kernel_params=(
# controller
"agent.config_file=/etc/agent-config.toml agent.aa_kbc_params=cc_kbc::${cc_kbc} agent.aa_attester=controller agent.kbs_ld=cc_cfs_controller_2024_k agent.confidential_image_digests=sha256:3fdee468d8e87278de4e790ae69985c6dd7cd0d99f22693ec63653d58e663114,sha256:5ce900f023fcea480b2f26d4148726ea5154f0943eb8f2395acd122ebf50f8ed,sha256:a5a8b3908d1775a78f5273012ac66090f37e763425149ae66a88af73c685816e,sha256:4737446dbc178164e3da845d2df80fb7a3318db85f70e2f47092943160cafafb,sha256:e93241d4d69cf19322c06374156a6706199dbcdea0ae7a22eaf5dd49988dbbc1,sha256:9a4130836e6eead0bfd1d6cca3e569a2ca27b82ce542927fd3da7e7eeff5fe22,sha256:8d02ed41cb7e78741aa110c0008168b1b42eba2b00776f76eb795d91d20358ab agent.enable_signature_verification=true agent.rest_api=all"
# metadata
"agent.config_file=/etc/agent-config.toml agent.aa_kbc_params=cc_kbc::${cc_kbc} agent.aa_attester=metadata agent.confidential_image_digests=sha256:db16cd196b8a37ba5f08414e6f6e71003d76665a5eac160cb75ad3759d8b3e29,sha256:c173338b58a2a104ad9891f1aafc22acc454246d961b6788d0ed5b0a00136699,sha256:81b2abb27d8855357eed735e2272888aafa3eab315ba6615a5eb38bb336063d4,sha256:51302100e4da8ab14e604013338cfe4f217c67563c2f36b54aa7233e60cb402f agent.enable_signature_verification=true agent.rest_api=all"
# security
"agent.config_file=/etc/agent-config.toml agent.aa_kbc_params=cc_kbc::${cc_kbc} agent.aa_attester=security agent.kbs_ld=cc_cfs_security_2024_k agent.confidential_image_digests=sha256:38eb50ceaf0bfe82a9c768e5537a012b58bb4fff0b0e4242e79dea992520c30f,sha256:51302100e4da8ab14e604013338cfe4f217c67563c2f36b54aa7233e60cb402f,sha256:2a023fb95034372ce145d5638c258a571850d25db58a1ec1880b7186c955ccd0 agent.enable_signature_verification=true agent.rest_api=all"
# workload
"agent.config_file=/etc/agent-config.toml agent.aa_kbc_params=cc_kbc::${cc_kbc} agent.aa_attester=workload agent.confidential_image_digests=sha256:db16cd196b8a37ba5f08414e6f6e71003d76665a5eac160cb75ad3759d8b3e29,sha256:51302100e4da8ab14e604013338cfe4f217c67563c2f36b54aa7233e60cb402f agent.enable_signature_verification=true agent.rest_api=all"
# debug
)

measurement_folder=measurements
rm -rf $measurement_folder  
mkdir -p $measurement_folder 

index=0
for (( i = 1; i <= num_cpus; i++ )); do
  for (( t=0; t<${#type_cpus[@]}; t++ )) do
    for (( c=0; c<${#kernel_params[@]}; c++ )) do 
      kernel_params_p1="tsc=reliable no_timer_check rcupdate.rcu_expedited=1 i8042.direct=1 i8042.dumbkbd=1 i8042.nopnp=1 i8042.noaux=1 noreplace-smp reboot=k cryptomgr.notests net.ifnames=0 pci=lastbus=0 console=hvc0 console=hvc1 quiet panic=1 nr_cpus=$i selinux=0 scsi_mod.scan=none"
      parameters="--mode snp \
      --vcpus=$i --vcpu-type=${type_cpus[$t]} \
      --ovmf=artifacts/snp/confidential-filesystems-snp.ovmf \
      --initrd=artifacts/snp/confidential-filesystems-snp.initrd \
      --kernel=artifacts/snp/confidential-filesystems-snp.vmlinux \
      --append='${kernel_params_p1} ${kernel_params[$c]}' \
      --output-format hex"
      content="sev-snp-measure $parameters"
      measurement=$(eval $content)
      ((index++))
      echo "measurement $index:" $measurement
      echo $parameters 
      echo ""
      cat > $measurement_folder/$measurement <<EOF
$parameters
EOF
      # echo $content
      # echo ""
    done
  done
done
