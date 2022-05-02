###############################################################
#                                                             #
#                     CLOUD FUNCTIONS                         #
#                                                             #
###############################################################

data "ibm_function_namespace" "namespace" {
  count = length(var.namespace) > 0 ? 1 : 0
  name  = var.namespace
}

resource "ibm_function_namespace" "namespace" {
  count             = length(var.namespace) > 0 ? 0 : 1
  name              = length(var.namespace) > 0 ? var.namespace : "functions-namespace"
  resource_group_id = data.ibm_resource_group.group.id
}

resource "null_resource" "actions" {
  count = length(local.actions)
  provisioner "local-exec" {
    command = "/bin/bash scripts/zip_cf.sh"

    environment = {
      FILENAME = local.actions[count.index].name
      FILEPATH = local.actions[count.index].code_path
    }
  }
}

resource "ibm_function_action" "action" {
  count                   = length(local.actions)
  name                    = local.actions[count.index].name
  namespace               = local.namespace_name
  user_defined_parameters = local.actions[count.index].user_defined_parameters

  exec {
    code_path = local.actions[count.index].code_path
    kind      = "nodejs:12"
  }
  depends_on = [null_resource.actions]
}

resource "ibm_function_action" "sequence" {
  name      = "assistant-curation-tf"
  namespace = local.namespace_name

  exec {
    kind       = "sequence"
    components = [for o in ibm_function_action.action : "/${local.namespace_id}/${o.name}"]
  }
}

resource "ibm_function_trigger" "trigger" {
  name      = "curation-trigger"
  namespace = local.namespace_name
  feed {
    name       = "/whisk.system/alarms/alarm"
    parameters = <<EOF
				[
					{
						"key":"cron",
						"value":"0 9 * * *"
					}
				]
	  	  EOF
  }
}

resource "ibm_function_rule" "rule" {
  name         = "curator"
  namespace    = local.namespace_name
  trigger_name = ibm_function_trigger.trigger.name
  action_name  = ibm_function_action.sequence.name
}
