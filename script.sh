#!/bin/bash

GITLAB_TOKEN="$GITLAB_TOKEN"
# GitLab API URL
GITLAB_API="https://development.idgital.com/api/v4"

# Function to add color to text or add background to the text
color_text() {
    echo -e "\e[$1m$2\e[0m"
}

get_group_id() {
    local group_name=$1
    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/groups?search=$group_name" | jq -r --arg name "$group_name" '.[] | select(.name==$name) | .id'
}


#Function to get project ID by name which is at root
get_root_project_id() {
    local project_name=$1
    local location=$2
    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects?search=$project_name" | jq -r --arg loc "$location" '.[] | select(.path_with_namespace==$loc) | .id'
}


# Function to get project ID by name within a group
get_project_id() {
    local group_id=$1
    local project_name=$2
    #curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/groups/$group_id/projects?search=$project_name" | jq -r --arg name "$project_name" '.[] | select(.name==$name) | .id'
    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/groups/$group_id/projects?search=$project_name" | jq -r '.[] | .id'
}

# Function to get project ID by name within a subgroup
get_sub_group_project_id() {
    local project_name=$1
    local location=$2
    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects?search=$project_name" | jq -r --arg name "$project_name" --arg loc "$location" '.[] | select(.path_with_namespace==$loc) | .id'
}

# Function to get open Merge Requests for a project
get_open_merge_requests() {
    local project_id=$1
    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects/$project_id/merge_requests?state=opened" | jq -r '.[] | "\(.id), \(.title), \(.state), \(.web_url)"'
}

get_merge_request_iid() {
    local project_id=$1
    local web_url=$2
    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects/$project_id/merge_requests?state=opened" | jq -r --arg url "$web_url" '.[] | select(.web_url == $url) | .iid'
}

# Function to get merge request details
get_assignee_and_reviewer() {
    local project_id=$1
    local web_url=$2
    local merge_request_iid=$(get_merge_request_iid $project_id $web_url)  # IID of the merge request (not ID)
    
    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects/36/merge_requests/$merge_request_iid" | jq -r \
    '. | "Assignee: \(.assignee.name // "None"), Reviewers: \(.reviewers[].name // "None")"'
}

# Function to get merge request details
get_author() {
    local merge_request_id=$1  # IID of the merge request (not ID)
    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects/$project_id/merge_requests?state=opened" | jq --arg id "$merge_request_id" '.[] | select(.id == ($id | tonumber)) | .author.name'
}

get_author_id(){
   local merge_request_id=$1  # IID of the merge request (not ID)
   curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects/$project_id/merge_requests?state=opened" | jq --arg id "$merge_request_id" '.[] | select(.id == ($id | tonumber)) | .author.id' 
}

get_author_email() {
    local merge_request_id=$1  # IID of the merge request (not ID)
    local author_id=$(get_author_id  $merge_request_id) 

    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/users/$author_id" | jq -r '.email'
}

get_assignees() {
    local merge_request_id=$1  # IID of the merge request (not ID)
    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects/$project_id/merge_requests?state=opened" | jq --arg id "$merge_request_id" -r '.[] | select(.id == ($id | tonumber)) | .assignees[].username'
}

get_assignee_id(){
   local merge_request_id=$1
   local username=$2
    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects/$project_id/merge_requests?state=opened" | jq --arg id "$merge_request_id" --arg username "$username" '.[] | select(.id == ($id | tonumber)) | .assignees[] | select(.username == $username) | .id'
}

get_assignee_email() {
    local merge_request_id=$1  # IID of the merge request (not ID)
    local username=$2
    local assignee_id=$(get_assignee_id $merge_request_id $username) 

    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/users/$assignee_id" | jq -r '.email'
}

get_reviewers() {
    local merge_request_id=$1  # IID of the merge request (not ID)
    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects/$project_id/merge_requests?state=opened" | jq --arg id "$merge_request_id" -r '.[] | select(.id == ($id | tonumber)) | .reviewers[].username'
}

get_reviewer_id(){
    local merge_request_id=$1
    local username=$2
    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects/$project_id/merge_requests?state=opened" | jq --arg id "$merge_request_id" --arg username "$username" '.[] | select(.id == ($id | tonumber)) | .reviewers[] | select(.username == $username) | .id'
}


get_reviewer_email() {
    local merge_request_id=$1  # IID of the merge request (not ID)
    local username=$2
    local reviewer_id=$(get_reviewer_id $merge_request_id $username) 

    curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/users/$reviewer_id" | jq -r '.email'
}

# Function to send email notifications
send_email() {

    local user_type="$1"
local user_name="$2"
user_name=$(echo "$user_name" | tr -d '"')
local user_email="$3"
local merge_request_url="$4"

echo -e "\n"
echo "$(color_text 43 "📬 Sending Email to $user_type $user_name")"

SUBJECT="Action Needed for Merge Request"

if [[ "$user_type" == "Assignee" ]]; then
    CONTENT="Hi $user_name!, we hope you are doing well. We would like to bring to your attention the Merge Request $merge_request_url assigned to you. To ensure a smooth review process, please review the details of the merge request and provide your feedback or approvals as necessary."
elif [[ "$user_type" == "Reviewer" ]]; then
    CONTENT="Hi $user_name!, we hope you are doing well. We would like to bring to your attention the Merge Request $merge_request_url that is awaiting your review. To help ensure smooth progress, kindly review the assigned merge request and provide your feedback or approvals where necessary."
else
    CONTENT="Hi $user_name!, we hope you are doing well. We would like to bring to your attention the Merge Request $merge_request_url you have created. To ensure smooth progress, please review the details of your merge request and address any feedback or updates required."
fi

# SendGrid API key
API_KEY="$SENDGRID_API_KEY"

# Email details
TO_EMAIL="$user_email"
FROM_EMAIL="no_reply@return.synthesishealthinc.com"

# Email Data in JSON format
JSON_DATA=$(cat <<EOF
{
  "personalizations": [{
    "to": [{
      "email": "$TO_EMAIL"
    }]
  }],
  "from": {
    "email": "$FROM_EMAIL"
  },
  "subject": "$SUBJECT",
  "content": [{
    "type": "text/plain",
    "value": "$CONTENT"
  }]
}
EOF
)

# Send the email using SendGrid API
response=$(curl --request POST \
--url https://api.sendgrid.com/v3/mail/send \
--header "Authorization: Bearer $API_KEY" \
--header "Content-Type: application/json" \
--data "$JSON_DATA")

# Check if the email was successfully sent
if [[ $? -eq 0 ]]; then
    echo "✅ Email sent successfully to $TO_EMAIL"
else
    echo "❌ Failed to send email."
fi
}

output_file="MR-Output.csv"
general(){
    echo "$(color_text 34 "🚀 Group: $group_name")"
    echo "$(color_text 36 "  📂 Project: $project_name")"
    echo -e "\n"
    echo "$(color_text 44 "📦 Fetching Merge Requests for Project ID: $project_id")"
    # Example usage within your script
    open_mrs=$(get_open_merge_requests "$project_id")
    if [ -z "$open_mrs" ]; then
        echo "$(color_text 33 "No open MRs found for project ID: $project_id")"
    else
        echo "$(color_text 33 "Open MRs for project ID: $project_id")"
        echo "$(color_text 32 "$open_mrs")"
        echo "$(color_text 47 "Going to process Open MRs")"
        # Loop through each line in the variable
        mr_number=1
        while IFS=',' read -r mr_id mr_title status url; do
            # Trim leading and trailing spaces
            mr_id=$(echo "$mr_id" | xargs)
            mr_title=$(echo "$mr_title" | xargs)
            status=$(echo "$status" | xargs)
            url=$(echo "$url" | xargs)
            echo -e "\n"
            echo "$(color_text 41 "✏️ MR Number: $mr_number")"
            echo "$(color_text 46 "Processing MR $url")"
            assignee_and_reviewer=$(get_assignee_and_reviewer $project_id $url)
            if [ "$assignee_and_reviewer" == "Assignee: None, Reviewers: None" ]; then
                echo "$(color_text 33 "For MR $url, $assignee_and_reviewer")"
                echo "$(color_text 42 "🔍 Finding Author")"
                author=$(get_author $mr_id )

                echo "$(color_text 32 "Author Name is : $author")"
                echo "$(color_text 46 "🕵️‍♂️ Processing Author: $author")"
                author_email=$(get_author_email $mr_id)

                echo "$(color_text 32 "Author Email is : $author_email")"

                send_email "Author" "$author" "$author_email" "$url"

            else
                echo "$(color_text 33 "For MR $url, $assignee_and_reviewer")"
                echo "$(color_text 42 "🔍 Finding Assignees")"
                get_assignees=$(get_assignees $mr_id)
                echo "Assignees User Name/s :[ $get_assignees ]"
                # Loop through each assignee and perform actions
                for assignee in $get_assignees; do
                    echo "$(color_text 46 "🕵️‍♂️ Processing Assignee: $assignee")"
                    
                    # Call a function or command to get assignee email
                    get_assignee_email=$(get_assignee_email "$mr_id" "$assignee")
                    
                    # Output the email or perform other actions
                    echo "$(color_text 32 "Assignee $assignee Email is $get_assignee_email")"

                    send_email "Assignee" "$assignee" "$get_assignee_email" "$url"
                done
                echo "$(color_text 42 "🔍 Finding Reviewers")"
                get_reviewers=$(get_reviewers $mr_id)
                echo "Reviewer/s  Name:[ $get_assignees ]"
                # Loop through each assignee and perform actions
                for reviewer in $get_reviewers; do
                    echo "$(color_text 46 "🕵️‍♂️ Processing reviewer: $reviewer")"
                    
                    # Call a function or command to get assignee email
                    get_reviewer_email=$(get_reviewer_email "$mr_id" "$reviewer")
                    
                    # Output the email or perform other actions
                    echo "$(color_text 32 "Reviewer $reviewer Email is $get_reviewer_email")"

                    send_email "Reviewer" "$reviewer" "$get_reviewer_email" "$url"
                done
            fi
            mr_number=$(( $mr_number + 1 ))
        done <<< "$open_mrs"
    fi
}

# Initialize an empty list (array)
projects_list=()  

get_all_projects(){
    PER_PAGE=100  # Number of projects per page

    # Initialize variables
    page=1
    has_more_pages=true

    # Loop through all pages
    while [ "$has_more_pages" = true ]; do
        # Fetch the list of projects for the current page
        projects=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API/projects?per_page=$PER_PAGE&page=$page")
        
        # Check if the curl command was successful
        if [ $? -ne 0 ]; then
            echo "Error: Failed to retrieve projects from GitLab."
            exit 1
        fi
        
        # Check if we received any projects
        if [ "$(echo "$projects" | jq '. | length')" -eq 0 ]; then
            has_more_pages=false
            break
        fi
        
        # Filter project data and store it in the array
        while IFS= read -r project_url; do
            projects_list+=("$project_url")  # Add the URL to the array
        done < <(echo "$projects" | jq -r '.[] | select(.web_url | contains("https://development.idgital.com/root/idgital") | not) | "\(.web_url)"' | sed 's|https://development.idgital.com/||')
        
        # Move to the next page
        ((page++))
    done
}

# Function to update project URLs
update_group_urls() {
    old_value=$1
    new_value=$2
    for i in "${!projects_list[@]}"; do
        # Replace "synthviewer/" with "SynthViewer/"
        if [[ "${projects_list[$i]}" == $old_value/* ]]; then
            projects_list[$i]="$new_value/${projects_list[$i]#$old_value/}"
        fi
    done
}

# Function to update project URLs
update_project_urls() {
    old_value="$1"  # The project name to be replaced (e.g., "ai_models_orchestrator")
    new_value="$2"  # The new project name (e.g., "AI_Models_Orchestrator")
    
    for i in "${!projects_list[@]}"; do
        # Check if the project URL contains the old project name at the end (after the last "/")
        if [[ "${projects_list[$i]}" == */$old_value ]]; then
            # Replace the old project name with the new project name
            projects_list[$i]="${projects_list[$i]/$old_value/$new_value}"
        fi
    done
}

get_all_projects

update_group_urls "synthviewer" "SynthViewer"

update_group_urls "synthai" "SynthAI"

update_group_urls "synthflow1" "SynthFlow"

update_group_urls "synthflow" "Synthflow"

update_group_urls "viewer" "Viewer"

update_group_urls "virtualmachines" "VirtualMachines"

update_group_urls "artem.nikiforov" "ArtemNikiforov"


update_group_urls "synthpm" "SynthPM"

update_project_urls "ai_models_orchestrator" "AI_Models_Orchestrator"

#update_project_urls "readme" "README"

# update_project_urls "case-report-follow-up" "Case Report Follow Up"

# Print all the project URLs stored in the list
echo "$(color_text 32 "Project URLs stored in the list:")"
for project_url in "${projects_list[@]}"; do
    echo "$(color_text 32 "$project_url")"
done

project_number=1
path=""
# Loop through the projects_list array
for line in "${projects_list[@]}"; do
    # Skip empty lines or lines starting with a comment #
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    echo -e "\n"
    # Process the line
    echo "$(color_text 45 "⚙️ Processing ${project_number} project : $line")"

    # Count the number of "/" in the line
    slash_count=$(echo "$line" | awk -F"/" '{print NF-1}')

    IFS="/" read -ra parts <<< "$line"

    if [ "$slash_count" -eq 4 ]; then
        path="${parts[0]}/${parts[1]}/${parts[2]}/${parts[3]}"
    elif [ "$slash_count" -eq 3 ]; then
        path="${parts[0]}/${parts[1]}/${parts[2]}"
    elif [ "$slash_count" -eq 2 ]; then
        path="${parts[0]}/${parts[1]}"
    else
        path="${parts[0]}"
    fi


    # Display the line and the count of "/"
    echo "$(color_text 40 "Project '${parts[$slash_count]}' is in the Group : $path")" 

    if [[ ${parts[0]} == "ArtemNikiforov" ]] || [[ ${parts[0]} == "ashahbaz" ]] || [[ ${parts[0]} == "mazhar.iqbal" ]] || [[ ${parts[0]} == "dale.seegmiller" ]] || [[ ${parts[0]} == "anderson.arendt" ]] || [[ ${parts[0]} == "marsalan" ]] || [[ ${parts[0]} == "justin.lacsina" ]] || [[ ${parts[0]} == "francisco.marques" ]] || [[ ${parts[0]} == "inna.kucherenko" ]] || [[ ${parts[0]} == "faizan.zahee" ]] || [[ ${parts[0]} == "justin.lacsina" ]] || [[ ${parts[0]} == "mohsin.saeed" ]] || [[ ${parts[0]} == "awaisali" ]] || [[ ${parts[0]} == "yengelmann" ]] || [[ ${parts[0]} == "evgeny.buzovsky" ]] || [[ ${parts[0]} == "syed.awaisali" ]] || [[ ${parts[0]} == "tbshill" ]]; then 
        continue
    fi

    if [[ ${parts[$slash_count]} == "AI_Models_Orchestrator" ]] || [[ ${parts[$slash_count]} == "case-report-follow-up" ]] || [[ ${parts[$slash_count]} == "cd-flow" ]] || [[ ${parts[$slash_count]} == "readme" ]]; then
        continue
    fi

    # Based on the count of slashes, print the appropriate parts
    if [[ $slash_count -eq 1 ]]; then
        # Setup Group Name As Environment Variable
        export group_name="${parts[0]}"
        echo "Exporting the Group Name as Environment Variable: $group_name"

        # Setup Project Name As Environment Variable
        export project_name="${parts[1]}"
        echo "Exporting the Project Name as Environment Variable: $project_name"

        # Get Group ID and Setup it As Environment Variable
        if [[ "$group_name" == "root" ]]; then
            echo "Group is root, So not getting group ID"

            # Get the project ID for group and Setup As Environment Variable 
            project_id=$(get_root_project_id $project_name $line)
            if [ -z "$project_id" ]; then
                echo "$(color_text 31 "❌ Project '${project_name}' not found in group '${group_name}'.")"
                exit 1
            fi
            export project_id
            echo "Exporting the Project ID as Environment Variable: $project_id"
        else
            group_id=$(get_group_id "${group_name}")
            if [ -z "$group_id" ]; then
                echo "$(color_text 31 "❌ Group '${group_name}' not found.")"
                exit 1
            fi
            export group_id
            echo "Exporting the Group ID as Environment Variable: $group_id"

            # Get the project ID for group and Setup As Environment Variable 
            project_id=$(get_project_id "$group_id" "${project_name}")
            if [ -z "$project_id" ]; then
                echo "$(color_text 31 "❌ Project '${project_name}' not found in group '${group_name}'.")"
                exit 1
            fi
            export project_id
            echo "Exporting the Project ID as Environment Variable: $project_id"
        fi
        # Call the general function
        general
    else
        # Setup Group Name As Environment Variable
        export group_name="${parts[0]}"
        echo "Exporting the Group Name as Environment Variable: $group_name"

        # Setup Project Name As Environment Variable
        export project_name="${parts[$slash_count]}"
        echo "Exporting the Project Name as Environment Variable: $project_name"

        # Get Group ID and Setup it As Environment Variable
        group_id=$(get_group_id "${group_name}")
        if [ -z "$group_id" ]; then
            echo "$(color_text 31 "❌ Group '${group_name}' not found.")"
            exit 1
        fi
        export group_id
        echo "Exporting the Group ID as Environment Variable: $group_id"

        # Get the project ID for group and Setup As Environment Variable 
        project_id=$(get_sub_group_project_id "${project_name}" "$line")
        if [ -z "$project_id" ]; then
            echo "$(color_text 31 "❌ Project '${project_name}' not found in group '${path}'.")"
            exit 1
        fi
        export project_id
        echo "Exporting the Project ID as Environment Variable: $project_id"

        # Call the general function
        general
    fi

    # Increment project_number
    project_number=$((project_number + 1))
done
