"""Round-trip .sysml files through a SysON instance: upload to a new project, download the export."""
import json, subprocess, sys, urllib.request, uuid
base, db_container, out_dir, files = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
def q(query, variables):
    req = urllib.request.Request(base + "/api/graphql", data=json.dumps({"query": query, "variables": variables}).encode(), headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req))
r = q("mutation($i:CreateProjectInput!){createProject(input:$i){... on CreateProjectSuccessPayload{project{currentEditingContext{id}}}}}",
      {"i": {"id": str(uuid.uuid4()), "name": "roundtrip", "templateId": "blank-project", "libraryIds": []}})
ec = r["data"]["createProject"]["project"]["currentEditingContext"]["id"]
for f in files:
    name = f.split("/")[-1]
    ops = {"query": "mutation($input:UploadDocumentInput!){uploadDocument(input:$input){__typename ... on UploadDocumentSuccessPayload{report} ... on ErrorPayload{messages{body}}}}",
           "variables": {"input": {"id": str(uuid.uuid4()), "editingContextId": ec, "file": None, "readOnly": False}}}
    out = subprocess.run(["curl", "-s", base + "/api/graphql/upload", "-F", f"operations={json.dumps(ops)}", "-F", 'map={"0":"variables.file"}', "-F", f"0=@{f}"], capture_output=True, text=True).stdout
    print(name, "upload:", json.loads(out)["data"]["uploadDocument"].get("report") or "OK")
    doc = subprocess.run(["docker", "exec", db_container, "psql", "-U", "username", "-d", "postgres", "-tAc",
                          f"select id from document where semantic_data_id='{ec}' and name='{name}';"], capture_output=True, text=True).stdout.strip()
    dest = f"{out_dir}/{name.replace('.sysml', '.export.sysml')}"
    subprocess.run(["curl", "-s", "-H", "Accept: text/html,*/*;q=0.8", "-o", dest, f"{base}/api/editingcontexts/{ec}/documents/{doc}"], check=True)
    print(" ->", dest)
