# Puppet and VMWare

There are two aspects to management of VMs using VMWare:  Provisioning and lifecycle of the VM as an instance on the hypervisor and ongoing management of the VM itself.  Puppet is able to manage both of these areas, the degree to which things are managed is up to the system administrator.

## Hypervisor Management of VMs
Puppet is able to remotely manage the VSphere hypervisor by using the [puppetlabs/vsphere](https://forge.puppetlabs.com/puppetlabs/vsphere) module.

The module runs from its associated node, EG the Puppet Master or some designated machine and with the help of the `rbvmomi` and `hocon` gems, is able to reach out to the VSphere server and configure individual VMWare VMs with the vmware_vm resource type.

Using the `vmware_vm` resource allows administrators to ensure that a VM is present/absent and also allows configuration of some VM settings.

The `vmware_vm` resource will only take ownership of VMs it is configured to manage so it can coexist with existing vm definitions.

It should be noted that VMs should only be managed in a single place: eg in puppet code or in the VSphere console.  Attempting to manage in both locations would result in conflict and as puppet typically runs every 30 minutes, would lead to Puppet having the final say in whether a VM should exist or not.

### Creating and maintaining VMs
Creating and maintaining VMs is as easy as adding a `vmware_vm` resource to your puppet code and configuring it appropriately.

### Deleting VMs
Deleting VMs managed by Puppet is somewhat more difficult.  There are two ways to do this:

#### Ensure absent
Individual VMs can marked with the `ensure => absent` attribute and this will cause puppet to remove the targeted VM on sight.  This action will be carried out on every subsequent puppet run.   The code to remove long-dead VMs may live on long beyond the removal of the original VM with this approach.

#### Remove from source code, then orchestrate a deletion
Another approach is to simply remove the old Puppet code that ensured the VM was present from the Puppet manifests and the perform the deletion using orchestration, eg:
* On the machine where VMWare provisioning is normally done from, use the puppet resource command to ensure the targeted VM is removed
* On the VSphere console, use the provided tools to remove the VM

Note that in both of these cases, you *MUST* first have removed the Puppet code to manage the VM instance *AND* have deployed this code to the Puppet master before attempting to delete the VM or Puppet will attempt to recreate it according to its last orders.

### VM Provisioning
Once a VM has started booting, it becomes just another Puppet node and management is more straight-forward.  For a while now, Puppet Enterprise has offered the so-called frictionless installer, which allows a node to download a script from the Puppet master using `curl` which then performs an agent installation and an initial Puppet run.

The installer can be combined with [Policy Based Autosigning](http://www.geoffwilliams.me.uk/Puppet/policy_based_autosigning) to fully automate the registration of new VMs with Puppet.

The overall steps to make this process work are:
1.  (on the puppet master) Enable policy based autosigning
2.  (on VSphere) alter the image to run the curl script
3. (optional) drop a custom fact into the image to assign a role to the node

The [VRealise vRO Puppet Plugin](https://solutionexchange.vmware.com/store/products/vrealize-orchestrator-vro-puppet-plugin) is able to support steps 2 and 3 of this process.  For step 1, a script needs to be written and placed on the Puppet Master that uses information embedded in the CSR against the VSphere API to ensure that the VM instance belongs to the cluster.

## Putting it all together
With both of these mechanisms in place, system administrators have full control of the VMWare VM lifecycle using puppet code.  The interface to VM creation therefore becomes writing Puppet code and performing operations via git.

While this is exactly what a lot of organisations want, this won't fit every deployment.  It should be noted that the VSphere GUI will be overridden by Puppet when using this technique.  If this is a problem or reduces overall usability, it is possible to continue to manage VMs exclusively through the GUI by simply not using the vmware_vm resource type at all and just setting up VM provisioning using the technique above.
