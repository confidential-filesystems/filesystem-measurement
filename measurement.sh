#!/usr/bin/env bash

num_cpus=${1:-240}
cc_kbc=${2:-"https://kbs.confidentialfilesystems.com:30443"}
type_cpus=('EPYC-v4')

kernel_params_p1='tsc=reliable no_timer_check rcupdate.rcu_expedited=1 i8042.direct=1 i8042.dumbkbd=1 i8042.nopnp=1 i8042.noaux=1 noreplace-smp reboot=k cryptomgr.notests net.ifnames=0 pci=lastbus=0 console=hvc0 console=hvc1 quiet panic=1 nr_cpus=$i selinux=0 scsi_mod.scan=none'
kernel_params_debug_p1='tsc=reliable no_timer_check rcupdate.rcu_expedited=1 i8042.direct=1 i8042.dumbkbd=1 i8042.nopnp=1 i8042.noaux=1 noreplace-smp reboot=k cryptomgr.notests net.ifnames=0 pci=lastbus=0 console=hvc0 console=hvc1 debug panic=1 nr_cpus=$i selinux=0 scsi_mod.scan=none agent.log=debug agent.debug_console agent.debug_console_vport=1026 initcall_debug'

digest_filesystem_operator="sha256:2fde3ee53bf641b76f43e6c6e3e13f46feacac90ac371cb85272cd06fe2d2004"
digest_ceph_csi_driver="sha256:760e80b944c88be646382ea4b2f00c5d1ff6268780dab81bb193f0426e913671"
digest_local_csi_driver="sha256:2ae1e1df4abdd8854a4e04ec964b9b75e09411f4041a5a3280af2933810fc69d"
digest_juicefs_csi_driver="sha256:c4e5839557d4df8c3d7c1378615ba33a548de25d903a9cb1a3b2ecfa4aaf00bd"
digest_kubernetes_csi_external_resizer="sha256:82d7fe58e40f04077ce27f3559e13129f6f3fb1b265d9e2b699a3010621ac1ee"
digest_csi_resizer="sha256:2dacadf83ef4126c076869d115bb6b9bdf0d71e6e5a44b518a087c9bca22fb0f"
digest_livenessprobe="sha256:f8cec70adc74897ddde5da4f1da0209a497370eaf657566e2b36bc5f0f3ccbd7"
digest_filesystem_init="sha256:c4e82633502deadb44fed6c9899811ad1ecdc37ad058c066dabfd199ff382a6c"
digest_filesystem_manager="sha256:4c10f9d963422d713ac5835831f6d44e420dfa91d1a05f6be628f05e23223763"
digest_redis="sha256:81b2abb27d8855357eed735e2272888aafa3eab315ba6615a5eb38bb336063d4"
digest_filesystem_sidecar="sha256:946c986cef31ecfad8c4ae0ff9fba2f1beb97f8de9ac3c97f769f5697ee4f71b"
digest_kbs="sha256:b5cffdf55a1a0379b637c18b4b1e7b23d4a6542ebea20b7f0c3826de8b2498f6"
digest_litestream="sha256:67fa3bbc48f996994af158e98d3574f2035a1d6d317876b16a038b32d842f1ef"

controller_kernel_params="agent.config_file=/etc/agent-config.toml agent.aa_kbc_params=cc_kbc::${cc_kbc} agent.aa_attester=controller agent.confidential_image_digests=${digest_filesystem_operator},${digest_ceph_csi_driver},${digest_local_csi_driver},${digest_juicefs_csi_driver},${digest_kubernetes_csi_external_resizer},${digest_csi_resizer},${digest_livenessprobe} agent.enable_signature_verification=true agent.rest_api=all"
metadata_kernel_params="agent.config_file=/etc/agent-config.toml agent.aa_kbc_params=cc_kbc::${cc_kbc} agent.aa_attester=metadata agent.confidential_image_digests=${digest_filesystem_init},${digest_filesystem_manager},${digest_redis},${digest_filesystem_sidecar} agent.enable_signature_verification=true agent.rest_api=all"
security_kernel_params="agent.config_file=/etc/agent-config.toml agent.aa_kbc_params=cc_kbc::${cc_kbc} agent.aa_attester=security agent.confidential_image_digests=${digest_filesystem_sidecar},${digest_kbs},${digest_litestream} agent.enable_signature_verification=true agent.rest_api=all"
workload_kernel_params="agent.config_file=/etc/agent-config.toml agent.aa_kbc_params=cc_kbc::${cc_kbc} agent.aa_attester=workload agent.confidential_image_digests=${digest_filesystem_init},${digest_filesystem_sidecar} agent.enable_signature_verification=true agent.rest_api=all"

kernel_params=(
# normal
"echo $kernel_params_p1 $controller_kernel_params"
"echo $kernel_params_p1 $metadata_kernel_params"
"echo $kernel_params_p1 $security_kernel_params"
"echo $kernel_params_p1 $workload_kernel_params"
# debug
"echo $kernel_params_debug_p1 $controller_kernel_params"
"echo $kernel_params_debug_p1 $metadata_kernel_params"
"echo $kernel_params_debug_p1 $security_kernel_params"
"echo $kernel_params_debug_p1 $workload_kernel_params"
)

measurement_folder=measurements
rm -rf $measurement_folder  
mkdir -p $measurement_folder 

index=0
for (( i = 1; i <= num_cpus; i++ )); do
  for (( t=0; t<${#type_cpus[@]}; t++ )) do
    for (( c=0; c<${#kernel_params[@]}; c++ )) do 
      append=$(eval ${kernel_params[$c]})
      parameters="--mode snp \
      --vcpus=$i --vcpu-type=${type_cpus[$t]} \
      --ovmf=artifacts/snp/confidential-filesystems-snp.ovmf \
      --initrd=artifacts/snp/confidential-filesystems-snp.initrd \
      --kernel=artifacts/snp/confidential-filesystems-snp.vmlinux \
      --append='$append' \
      --output-format hex --guest-features 0x1"
      content="sev-snp-measure $parameters"
      measurement=$(eval $content)
      ((index++))
      echo "measurement $index:" $measurement
      echo $parameters 
      echo ""
      cat > $measurement_folder/$measurement <<EOF
$parameters
EOF
    done
  done
done
