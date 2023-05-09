work_dir := $(shell pwd)
work_dir_name := $(notdir $(work_dir))
current_date := $(shell date '+%Y-%m-%d')
current_time := $(shell date '+%H.%M.%S')

project := $(shell grep -E "^project_name\s+=\s+" $(work_dir)/terraform.tfvars | cut -d '=' -f2 | sed -e 's/^ //g' -e 's/"//g')
project_aws_region := $(shell grep -E "^region\s+=\s+" $(work_dir)/backend.conf | cut -d '=' -f2 | sed -e 's/^ //g' -e 's/"//g')
project_bucket := $(shell grep -E "^bucket\s+=\s+" $(work_dir)/backend.conf | cut -d '=' -f2 | sed -e 's/^ //g' -e 's/"//g')

terraform_remote_state := $(shell grep -E "^key\s+=\s+" $(work_dir)/backend.conf | cut -d '=' -f2 | sed -e 's/^ //g' -e 's/"//g')
terraform_lock_table := $(shell grep -E "^dynamodb_table\s+=\s+" $(work_dir)/backend.conf | cut -d '=' -f2 | sed -e 's/^ //g' -e 's/"//g')
terraform_tfvars_secret := $(shell cat  $(work_dir)/tfvars.secret)
terraform_tfvars_file_name := terraform.tfvars
terraform_local_cache := ./.terraform ./tmp/* ./terraform.tfvars ./.terraform.lock.hcl

# Options
resource :=
secret := $(terraform_tfvars_secret)



all: help

help:
	$(info Available targets:)
	$(info ------------------)
	@grep -Eo '^[a-z-]+[:][a-z[:space:].-]*$$' "$(work_dir)/Makefile" | cut -d':' -f1 \
	  && echo "---" \
	  && echo "You may use 'resource' option to limit operations (if supported by Terraform). Example: 'make destroy resource=aws_vpc.default'"

init: # check-remote-state check-remote-lock
	@cd "$(work_dir)" \
	  && echo "Formatting:" \
	  && terraform fmt \
	  && echo "---" \
	  && which tflint && tflint . \
	  && terraform init

# Add this after migration --backend-config=backend.conf

pull-tfvars-file:
	$(info AWS Secret to pull from: "$(terraform_tfvars_secret)". You may change this value using "secret" option: "make pull-tfvars-file secret='aws-secret-id'")
	$(info AWS Secret must contain key "tfvars" with base64 encoded value of "$(terraform_tfvars_file_name)" content)
	$(info Additional software required to pull "$(terraform_tfvars_file_name)" content from AWS SecretsManager: aws, jq, base64)
	@cd "$(work_dir)" \
	  && cp -v ./$(terraform_tfvars_file_name) ./tmp/$(terraform_tfvars_file_name).$(current_date)T$(current_time) || true \
	  && aws secretsmanager get-secret-value --output "text" --secret-id "$(secret)" --query 'SecretString' | jq -r '.tfvars' | base64 -d > ./$(terraform_tfvars_file_name)

push-tfvars-file:
	$(info AWS Secret must already exist!)
	$(info AWS Secret to push to: "$(terraform_tfvars_secret)". You may change this value using "secret" option: "make pull-tfvars-file secret='aws-secret-id'")
	@cd "$(work_dir)" \
	  && stat ./$(terraform_tfvars_file_name) 1>/dev/null \
	  && printf '{"tfvars": "%s"}' "$$(base64 -w0 ./$(terraform_tfvars_file_name))" > ./$(terraform_tfvars_file_name).base64 \
	  && aws secretsmanager put-secret-value --secret-id "$(secret)" --secret-string file://./$(terraform_tfvars_file_name).base64 \
	  && rm -f ./$(terraform_tfvars_file_name).base64

list:
	@cd "$(work_dir)" \
	  terraform state list

show:
	@cd "$(work_dir)" \
	  && if [ "$(resource)z" = "z" ]; then \
	       echo "'resource' required" >&2; \
	     else \
	       terraform state show '$(resource)'; \
	     fi

plan: # check-remote-state check-remote-lock
	@cd "$(work_dir)" \
	  && echo "Formatting:" \
	  && terraform fmt \
	  && echo "---" \
	  && terraform plan

validate: init
	@cd "$(work_dir)" \
	  && echo "Formatting:" \
	  && terraform fmt \
	  ; echo "---" \
	  ; which tfsec && tfsec --tfvars-file "$(work_dir)/terraform.tfvars" . \
	  ; echo "---" \
	  ; which checkov && checkov --quiet --directory "$(work_dir)"

refresh: check-remote-state check-remote-lock
	@cd "$(work_dir)" \
	  && terraform apply -refresh-only

apply: # check-remote-state check-remote-lock
	@cd "$(work_dir)" \
	  && echo "Formatting:" \
	  && terraform fmt \
	  && echo "---" \
	  ; [ -z "$(resource)" ] && terraform apply || true \
	  ; [ -n "$(resource)" ] && terraform apply --target $(resource) || true

output:
	@cd "$(work_dir)" \
	  && terraform output

list-resources:
	@cd "$(work_dir)" \
	  && terraform state list

show-resource:
	@cd "$(work_dir)" \
	  && [ -z "$(resource)" ] && echo "Provide resource as: make show resource=<resource.name>" || terraform state show $(resource)

rm-from-state:
	@cd "$(work_dir)" \
	  && [ -z "$(resource)" ] && echo "Provide resource as: make rm resource=<resource.name>" || terraform state rm $(resource)

destroy:
	@cd "$(work_dir)" \
	  && [ -z "$(resource)" ] && terraform destroy || terraform destroy --target $(resource)

.clean-confirmation:
	$(info These resources will be deleted:)
	@cd "$(work_dir)" \
	  && echo $(terraform_local_cache) \
	  && read -r -p "Type 'yes' to confirm: " _answer \
	  && /bin/sh -c "if [ """$${_answer}""" = """yes""" ]; then true; else false; fi"

clean-project-dir: .clean-confirmation
	@cd "$(work_dir)" \
	  && rm -rf $(terraform_local_cache)

check-remote-state:
	@aws s3 ls | cut -d' ' -f3 | grep -qE "^$(project_bucket)$$" \
	  && echo "Remote state path: 's3://$(project_bucket)/$(terraform_remote_state)'" \
	  || { echo "Remote state path does not exists, configure it in 'backend.conf' and create with: 'make configure-remote-state'"; return 1; }

check-remote-lock:
	@aws dynamodb list-tables --query 'TableNames[*]' --output 'text' | grep -qE "(^|\s)$(terraform_lock_table)($$|\s)" \
	  && echo "DynamoDB table for remote lock: 'dynamodb:$(terraform_lock_table)'" \
	  || { echo "DynamoDB table for remote lock does not exists, configure it in 'backend.conf' and create with: 'make configure-remote-lock'"; return 1; }

configure-remote-state:
	$(info Create project bucket [$(project_bucket)] in region [$(project_aws_region)]:)
	$(info ----------------------------------------------------------------------------)
	@aws s3 ls | cut -d' ' -f3 | grep -qE "^$(project_bucket)$$" \
	  && echo "S3 bucket '$(project_bucket)' already exists!" \
	  || { aws s3 mb s3://$(project_bucket) --region $(project_aws_region) \
	    && aws s3api put-bucket-encryption --bucket $(project_bucket) --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
	    && aws s3api put-public-access-block --bucket $(project_bucket) --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
	    && echo "S3 bucket '$(project_bucket)' created"; }

configure-remote-lock:
	$(info Create DynamoDB table [$(terraform_lock_table)] in region [$(project_aws_region)] to store Terraform lock state:)
	$(info ----------------------------------------------------------------------------------------------------------------)
	@aws dynamodb list-tables --query 'TableNames[*]' --output 'text' | grep -qE "(^|\s)$(terraform_lock_table)($$|\s)" \
	  && echo "DynamoDB table '$(terraform_lock_table)' already exists!" \
	  || { aws dynamodb create-table --table-name $(terraform_lock_table) \
	         --attribute-definitions "AttributeName=LockID,AttributeType=S" \
	         --key-schema "AttributeName=LockID,KeyType=HASH" \
	         --provisioned-throughput "ReadCapacityUnits=5,WriteCapacityUnits=5" \
	         --region $(project_aws_region) \
	    && echo "DynamoDB table '$(terraform_lock_table)' created"; }
