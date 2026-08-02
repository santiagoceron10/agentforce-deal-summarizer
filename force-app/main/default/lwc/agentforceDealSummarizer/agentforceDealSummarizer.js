import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import summarizeDeal from '@salesforce/apex/AgentforceDealSummaryController.summarizeDeal';

/**
 * agentforceDealSummarizer
 * ------------------------
 * Placed on the Opportunity record page. On demand, calls Apex to gather the
 * deal's context and asks an Agentforce agent for a concise summary (health,
 * momentum, risks, recommended next steps), with loading/error states and a
 * copy-to-clipboard action.
 *
 * SCAFFOLD NOTE: Not deployed or tested against a live org. The underlying
 * Agentforce invocation is an unwired swap-point in the Apex controller, so
 * until it is wired the "Summarize Deal" action surfaces a clear error.
 */
export default class AgentforceDealSummarizer extends LightningElement {
    @api recordId;

    summary = '';
    isLoading = false;
    errorMessage = '';

    get hasSummary() {
        return !this.isLoading && this.summary && this.summary.length > 0;
    }

    get hasError() {
        return !this.isLoading && this.errorMessage && this.errorMessage.length > 0;
    }

    async handleSummarize() {
        this.isLoading = true;
        this.errorMessage = '';
        this.summary = '';

        try {
            const result = await summarizeDeal({ opportunityId: this.recordId });
            this.summary = result;
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleCopy() {
        if (!this.summary) {
            return;
        }
        try {
            if (navigator.clipboard && navigator.clipboard.writeText) {
                await navigator.clipboard.writeText(this.summary);
            } else {
                this.legacyCopy(this.summary);
            }
            this.toast('Copied', 'Summary copied to clipboard.', 'success');
        } catch (e) {
            this.toast('Copy failed', 'Could not copy the summary.', 'error');
        }
    }

    legacyCopy(text) {
        const el = document.createElement('textarea');
        el.value = text;
        this.template.host.appendChild(el);
        el.select();
        document.execCommand('copy');
        this.template.host.removeChild(el);
    }

    reduceError(error) {
        if (Array.isArray(error && error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error && error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        if (error && typeof error.message === 'string') {
            return error.message;
        }
        return 'An unexpected error occurred while summarizing the deal.';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
