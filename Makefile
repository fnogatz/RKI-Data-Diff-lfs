curr_dir=$(shell pwd)
DIR ?= $(curr_dir)/data
FILENAME ?= RKI_COVID19

URL_METADATA ?= https://www.arcgis.com/sharing/rest/content/items/f10774f1c63e40168479a1feb6c7ca74?f=json
URL_DATASET ?= https://www.arcgis.com/sharing/rest/content/items/f10774f1c63e40168479a1feb6c7ca74/data

LOCK:
	curl -s -X GET -H "Accept: application/json" $(URL_METADATA) 2>&1 | sed -E 's/.*"modified":([0-9]+).*/\1/' > $(DIR)/LOCK

data_dir:
	mkdir -p $(DIR)

csv.download: data_dir
	@echo "# Load remote metadata"
	$(eval MODIFIED=$(shell curl -s -X GET -H "Accept: application/json" $(URL_METADATA) 2>&1 | sed -E 's/.*"modified":([0-9]+).*/\1/'))
	@echo "# Check modification time $(MODIFIED) against LOCK: CSV file updated?"
	!(echo -n $(MODIFIED) | cmp -s $(DIR)/LOCK -)
	@echo "# Start download remote CSV file"
	curl -L $(URL_DATASET) --output $(DIR)/$(FILENAME).csv
	@echo "# Update LOCK by most recent modification time $(MODIFIED)"
	echo -n $(MODIFIED) > $(DIR)/LOCK

test:
	npm test
