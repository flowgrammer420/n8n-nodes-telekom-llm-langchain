import type {
	INodeType,
	INodeTypeDescription,
	ISupplyDataFunctions,
	SupplyData,
	ILoadOptionsFunctions,
	INodePropertyOptions,
} from 'n8n-workflow';
import { NodeConnectionTypes } from 'n8n-workflow';
import { ChatOpenAI } from '@langchain/openai';

export class TelekomLlmChatModel implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'Telekom LLM Chat Model',
		name: 'telekomLlmChatModel',           // WICHTIG: kleiner Buchstabe am Anfang (n8n-Konvention)
		icon: { light: 'file:telekom.svg', dark: 'file:telekom.dark.svg' },
		group: ['transform'],
		version: 1,
		description: 'T-Systems LLM Hub – OpenAI-kompatibler Chat-Model',
		defaults: { name: 'Telekom LLM Chat Model' },
		inputs: [],
		outputs: [NodeConnectionTypes.AiLanguageModel],
		outputNames: ['Model'],

		codex: {
			categories: ['AI'],
			subcategories: {
				AI: ['Language Models', 'Root Nodes'],
				'Language Models': ['Chat Models (Recommended)'],
			},
			resources: {
				primaryDocumentation: [{ url: 'https://llmhub.t-systems.net' }],
			},
		},

		credentials: [{ name: 'telekomLlmApi', required: true }],

		requestDefaults: {
			baseURL: '={{ $credentials?.baseUrl }}',
			ignoreHttpStatusErrors: true,
		},

		properties: [
			{
				displayName: 'Hinweis',
				name: 'notice',
				type: 'notice',
				default: 'Verbinde diesen Node mit einem AI Agent oder Chain für beste Ergebnisse.',
			},
			{
				displayName: 'Model',
				name: 'model',
				type: 'options',
				noDataExpression: true,
				typeOptions: { loadOptionsMethod: 'getModels' },
				default: 'llama-3.3-70B-Instruct',
				description: 'Wähle das gewünschte Modell aus dem T-Systems LLM Hub',
			},
			{
				displayName: 'Optionen',
				name: 'options',
				type: 'collection',
				placeholder: 'Erweiterte Parameter',
				default: {},
				options: [
					{ displayName: 'Temperature', name: 'temperature', type: 'number', default: 0.7, typeOptions: { minValue: 0, maxValue: 2, numberPrecision: 2 } },
					{ displayName: 'Max Tokens', name: 'maxTokens', type: 'number', default: -1, description: '-1 = keine Begrenzung' },
					{ displayName: 'Top P', name: 'topP', type: 'number', default: 1, typeOptions: { minValue: 0, maxValue: 1, numberPrecision: 2 } },
				],
			},
		],
	};

	methods = {
		loadOptions: {
			async getModels(this: ILoadOptionsFunctions): Promise<INodePropertyOptions[]> {
				try {
					const credentials = await this.getCredentials('telekomLlmApi');
					const baseUrl = (credentials.baseUrl as string)?.replace(/\/+$/, '');

					const response = await this.helpers.httpRequestWithAuthentication.call(this, 'telekomLlmApi', {
						method: 'GET',
						url: '/models',
						baseURL: baseUrl,
					});

					if (!response?.data?.length) throw new Error('Keine Modelle empfangen');

					return response.data
						.map((m: any) => ({ name: m.id, value: m.id }))
						.sort((a: INodePropertyOptions, b: INodePropertyOptions) => a.name.localeCompare(b.name));
				} catch {
					return [
						{ name: 'llama-3.3-70B-Instruct', value: 'llama-3.3-70B-Instruct' },
						{ name: 'claude-3-5-sonnet', value: 'claude-3-5-sonnet' },
						{ name: 'gemini-2.5-flash', value: 'gemini-2.5-flash' },
					];
				}
			},
		},
	};

	async supplyData(this: ISupplyDataFunctions, itemIndex = 0): Promise<SupplyData> {
		const credentials = await this.getCredentials('telekomLlmApi');
		const modelName = this.getNodeParameter('model', itemIndex) as string;
		const options = this.getNodeParameter('options', itemIndex, {}) as any;

		const baseUrl = (credentials.baseUrl as string)?.replace(/\/+$/, '');

		const model = new ChatOpenAI({
			model: modelName,
			apiKey: credentials.apiKey as string,
			configuration: { baseURL: baseUrl },
			temperature: options.temperature ?? 0.7,
			maxTokens: options.maxTokens === -1 ? undefined : options.maxTokens,
			topP: options.topP ?? 1,
		});

		return { response: model };
	}
}