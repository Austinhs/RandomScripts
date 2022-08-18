#!/bin/sh

ORG="DivineAnarchy"
REPO="decentralized-app"
SERVICE_ACCOUNT_NAME="Github-Actions-decenteralized-app"
PROJECT_ID="divine-anarchy-356723"
FILE_PATH="build/wif-${REPO}.json"
ROLES=(
	"artifactregistry.admin"
	"iam.serviceAccountUser"
	"run.admin"
	"cloudsql.admin"
)

REPO_PATH="${ORG}/${REPO}"
WORKLOAD_POOL="${REPO}"
SERVICE_ACCOUNT="${REPO}"
PROVIDER="${REPO}"

echo "Create service account"
gcloud iam service-accounts create "${SERVICE_ACCOUNT}" \
	--project "${PROJECT_ID}"

echo "Enable IAM Credential API for project"
gcloud services enable iamcredentials.googleapis.com \
	--project "${PROJECT_ID}"

echo "Create workload identity pool"
gcloud iam workload-identity-pools create "${WORKLOAD_POOL}" \
	--project="${PROJECT_ID}" \
	--location="global" \
	--display-name="${WORKLOAD_POOL}"

echo "Get workload identity pool path"
WORKLOAD_IDENTITY_POOL_ID=`gcloud iam workload-identity-pools describe "${WORKLOAD_POOL}" \
	--project="${PROJECT_ID}" \
	--location="global" \
	--format="value(name)"`

echo "Create OIDC provider"
gcloud iam workload-identity-pools providers create-oidc "${PROVIDER}" \
	--project="${PROJECT_ID}" \
	--location="global" \
	--workload-identity-pool="${WORKLOAD_POOL}" \
	--display-name="${PROVIDER}" \
	--attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
	--issuer-uri="https://token.actions.githubusercontent.com"

for role in "${ROLES[@]}"; do
	echo "Add role ${role} to service account"
	gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
		--member "serviceAccount:${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com" \
		--role "roles/${role}" > /dev/null 2>&1
done

echo "Adding role: roles/iam.workloadIdentityUser for GitHub Repo path"
gcloud iam service-accounts add-iam-policy-binding "${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com" \
	--project="${PROJECT_ID}" \
	--role="roles/iam.workloadIdentityUser" \
	--member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository/${REPO_PATH}"

echo "Get OIDC provider path"
GITHUB_WORKLOAD_IDENTITY_PROVIDER=`gcloud iam workload-identity-pools providers describe "${PROVIDER}" \
	--project="${PROJECT_ID}" \
	--location="global" \
	--workload-identity-pool="${WORKLOAD_POOL}" \
	--format="value(name)"`

JSON_FMT='{
	"PROJECT_ID": "%s",
	"REPO_PATH": "%s",
	"SERVICE_ACCOUNT_NAME": "%s",
	"WORKLOAD_POOL": "%s",
	"SERVICE_ACCOUNT": "%s",
	"PROVIDER": "%s",
	"WORKLOAD_IDENEITY_POOL_ID": "%s",
	"GITHUB_WORKLOAD_IDENTITY_PROVIDER": "%s"
}'

echo "Save WIF information to ${FILE_PATH}"
[ -d build ] || mkdir build
rm ${FILE_PATH} >> /dev/null 2>&1
printf "$JSON_FMT" \
	"${PROJECT_ID}" \
	"${REPO_PATH}" \
	"${SERVICE_ACCOUNT_NAME}" \
	"${WORKLOAD_POOL}" \
	"${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com" \
	"${PROVIDER}" \
	"${WORKLOAD_IDENTITY_POOL_ID}" \
	"${GITHUB_WORKLOAD_IDENTITY_PROVIDER}" \
	>> ${FILE_PATH}
