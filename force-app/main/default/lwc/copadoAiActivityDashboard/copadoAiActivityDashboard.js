import { LightningElement } from 'lwc';
import getActivitySummary from '@salesforce/apex/CopadoAiActivityController.getActivitySummary';
import getRawActivity from '@salesforce/apex/CopadoAiActivityController.getRawActivity';

const TOTAL_ROW_KEY = 'grand-total';
const TOTAL_ROW_CLASS = 'slds-text-title_bold';

const SUMMARY_COLUMNS = [
    { label: 'User ID', fieldName: 'userId', type: 'text', sortable: true, cellAttributes: { class: { fieldName: 'rowClass' } } },
    { label: 'Total Prompts', fieldName: 'totalPrompts', type: 'number', sortable: true, cellAttributes: { class: { fieldName: 'rowClass' } } },
    { label: 'Prompt Limit', fieldName: 'messageLimit', type: 'number', sortable: true, cellAttributes: { class: { fieldName: 'rowClass' } } }
];

const RAW_COLUMNS = [
    { label: 'Timestamp', fieldName: 'timestamp', type: 'date', sortable: true,
        typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
    { label: 'User ID', fieldName: 'userId', type: 'text', sortable: true },
    { label: 'Action', fieldName: 'action', type: 'text', sortable: true },
    { label: 'Workspace', fieldName: 'workspaceId', type: 'text', sortable: false },
    { label: 'Message', fieldName: 'prompt', type: 'text', sortable: false }
];

export default class CopadoAiActivityDashboard extends LightningElement {
    isLoading = false;
    hasError = false;
    errorMessage = null;
    activityData = [];
    startDate;
    endDate;
    viewMode = 'summary';
    lastRefreshed = null;
    sortedBy;
    sortedDirection = 'asc';
    requestId = 0;

    connectedCallback() {
        const end = new Date();
        const start = new Date();
        start.setDate(end.getDate() - 30);
        this.endDate = this.toIsoDate(end);
        this.startDate = this.toIsoDate(start);
        this.fetchActivity();
    }

    get columns() {
        return this.viewMode === 'raw' ? RAW_COLUMNS : SUMMARY_COLUMNS;
    }

    get summaryVariant() {
        return this.viewMode === 'summary' ? 'brand' : 'neutral';
    }

    get rawVariant() {
        return this.viewMode === 'raw' ? 'brand' : 'neutral';
    }

    get showTable() {
        return !this.isLoading && !this.hasError;
    }

    handleDateChange(event) {
        const field = event.target.name;
        if (field !== 'startDate' && field !== 'endDate') {
            return;
        }
        this[field] = event.target.value;
        this.fetchActivity();
    }

    handleViewModeChange(event) {
        const mode = event.target.dataset.mode;
        if (!mode || mode === this.viewMode) {
            return;
        }
        this.viewMode = mode;
        this.sortedBy = undefined;
        this.sortedDirection = 'asc';
        this.fetchActivity();
    }

    handleRefresh() {
        this.fetchActivity();
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        const rows = this.activityData.filter((row) => row.rowKey !== TOTAL_ROW_KEY);
        const sorted = [...rows].sort((left, right) => {
            const leftValue = left[fieldName] ?? '';
            const rightValue = right[fieldName] ?? '';
            let comparison = 0;
            if (leftValue > rightValue) {
                comparison = 1;
            } else if (leftValue < rightValue) {
                comparison = -1;
            }
            return sortDirection === 'asc' ? comparison : -comparison;
        });
        this.activityData = this.withGrandTotal(sorted);
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
    }

    async fetchActivity() {
        const requestId = ++this.requestId;
        this.isLoading = true;
        this.hasError = false;
        this.errorMessage = null;
        try {
            const data = this.viewMode === 'raw'
                ? await getRawActivity({
                    startDate: this.startDate,
                    endDate: this.endDate,
                    limitCount: 200
                })
                : await getActivitySummary({
                    startDate: this.startDate,
                    endDate: this.endDate
                });
            if (requestId !== this.requestId) {
                return;
            }
            const rows = (data || []).map((row, index) => ({
                ...row,
                rowKey: `${row.eventId || row.userId || 'row'}-${index}`
            }));
            this.activityData = this.withGrandTotal(rows);
            this.lastRefreshed = new Date().toISOString();
        } catch (error) {
            if (requestId !== this.requestId) {
                return;
            }
            this.activityData = [];
            this.hasError = true;
            this.errorMessage = this.reduceError(error);
        } finally {
            if (requestId === this.requestId) {
                this.isLoading = false;
            }
        }
    }

    withGrandTotal(rows) {
        if (this.viewMode !== 'summary') {
            return rows;
        }
        const totalPrompts = rows.reduce((total, row) => total + (Number(row.totalPrompts) || 0), 0);
        const messageLimit = rows.reduce((total, row) => total + (Number(row.messageLimit) || 0), 0);
        return [
            ...rows,
            {
                rowKey: TOTAL_ROW_KEY,
                userId: 'Grand Total',
                totalPrompts,
                messageLimit,
                rowClass: TOTAL_ROW_CLASS
            }
        ];
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'Unable to load Copado AI activity.';
    }

    toIsoDate(value) {
        const month = String(value.getMonth() + 1).padStart(2, '0');
        const day = String(value.getDate()).padStart(2, '0');
        return `${value.getFullYear()}-${month}-${day}`;
    }
}