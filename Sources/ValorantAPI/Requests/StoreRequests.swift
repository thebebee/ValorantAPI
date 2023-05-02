import Foundation
import Protoquest
import ErgonomicCodable

extension ValorantClient {
	public func getStorefront() async throws -> Storefront {
		try await send(StorefrontRequest(playerID: userID))
	}
	
	public func getStoreWallet() async throws -> StoreWallet {
		try await send(StoreWalletRequest(playerID: userID))
	}
	
	public func getStoreOffers() async throws -> [StoreOffer] {
		try await send(StoreOffersRequest()).offers
	}
}

private struct StorefrontRequest: GetJSONRequest, GameDataRequest {
	var playerID: Player.ID
	
	var path: String {
		"/store/v2/storefront/\(playerID)"
	}
	
	typealias Response = Storefront
}

private struct StoreWalletRequest: GetJSONRequest, GameDataRequest {
	var playerID: Player.ID
	
	var path: String {
		"/store/v1/wallet/\(playerID)"
	}
	
	typealias Response = StoreWallet
}

struct StoreOffersRequest: GetJSONRequest, GameDataRequest {
	var path: String {
		"/store/v1/offers/"
	}
	
	struct Response: Decodable {
		var offers: [StoreOffer]
		// technically also contains "upgrade currency offers"
		
		private enum CodingKeys: String, CodingKey {
			case offers = "Offers"
		}
	}
}

public struct Storefront: Codable {
	public var featuredBundle: FeaturedBundle
	public var skinsPanelLayout: SkinsPanelLayout
	public var nightMarket: NightMarket?
	
	private enum CodingKeys: String, CodingKey {
		case featuredBundle = "FeaturedBundle"
		case skinsPanelLayout = "SkinsPanelLayout"
		case nightMarket = "BonusStore"
	}
	
	public struct FeaturedBundle: Codable {
		public var bundles: [StoreBundle]
		
		private enum CodingKeys: String, CodingKey {
			case bundles = "Bundles"
		}
	}
	
	public struct SkinsPanelLayout: Codable {
		public var singleItemOffers: [StoreOffer.ID]
		public var remainingDuration: TimeInterval
		
		private enum CodingKeys: String, CodingKey {
			case singleItemOffers = "SingleItemOffers"
			case remainingDuration = "SingleItemOffersRemainingDurationInSeconds"
		}
	}
	
	public struct NightMarket: Codable {
		public var offers: [Offer]
		public var remainingDuration: TimeInterval
		
		private enum CodingKeys: String, CodingKey {
			case offers = "BonusStoreOffers"
			case remainingDuration = "BonusStoreRemainingDurationInSeconds"
		}
		
		public struct Offer: Identifiable, Codable {
			public var id: ObjectID<Self, LowercaseUUID>
			public var offer: StoreOffer
			public var discountPercent: Int
			@StringKeyedDictionary
			public var discountedCosts: [Currency.ID: Int]
			public var isSeen: Bool
			
			private enum CodingKeys: String, CodingKey {
				case id = "BonusOfferID"
				case offer = "Offer"
				case discountPercent = "DiscountPercent"
				case discountedCosts = "DiscountCosts"
				case isSeen = "IsSeen"
			}
		}
	}
}

public struct StoreBundle: Identifiable, Codable {
	public var id: ObjectID<Self, LowercaseUUID>
	public var assetID: Asset.ID
	public var currencyID: Currency.ID
	public var remainingDuration: TimeInterval
	/// whether the bundle can only be bought
	public var isWholesaleOnly: Bool
	public var items: [Item]
	
	private enum CodingKeys: String, CodingKey {
		case id = "ID"
		case assetID = "DataAssetID"
		case currencyID = "CurrencyID"
		case remainingDuration = "DurationRemainingInSeconds"
		case isWholesaleOnly = "WholesaleOnly"
		case items = "Items"
	}
	
	public struct Item: Codable, Identifiable {
		public var info: Info
		public var basePrice: Int
		public var currencyID: Currency.ID
		/// 0 = full price, 1 = discounted to free
		public var discount: Double
		public var discountedPrice: Int
		public var isPromoItem: Bool
		
		public var id: some Hashable {
			info.itemID
		}
		
		private enum CodingKeys: String, CodingKey {
			case info = "Item"
			case basePrice = "BasePrice"
			case currencyID = "CurrencyID"
			case discount = "DiscountPercent"
			case discountedPrice = "DiscountedPrice"
			case isPromoItem = "IsPromoItem"
		}
		
		public struct Info: Codable, _UntypedItem {
			public var itemTypeID: ItemType.ID
			public var itemID: LowercaseUUID
			public var amount: Int
			
			private enum CodingKeys: String, CodingKey {
				case itemTypeID = "ItemTypeID"
				case itemID = "ItemID"
				case amount = "Amount"
			}
		}
	}
	
	public enum Asset {
		public typealias ID = ObjectID<Self, LowercaseUUID>
	}
}

public struct StoreOffer: Identifiable, Codable {
	public var id: ObjectID<Self, LowercaseUUID>
	public var isDirectPurchase: Bool
	public var startDate: Date
	@StringKeyedDictionary
	public var cost: [Currency.ID: Int]
	public var rewards: [Reward]
	
	private enum CodingKeys: String, CodingKey {
		case id = "OfferID"
		case isDirectPurchase = "IsDirectPurchase"
		case startDate = "StartDate"
		case cost = "Cost"
		case rewards = "Rewards"
	}
	
	public struct Reward: Codable, _UntypedItem {
		public var itemTypeID: ItemType.ID
		public var itemID: LowercaseUUID
		public var quantity: Int
		
		private enum CodingKeys: String, CodingKey {
			case itemTypeID = "ItemTypeID"
			case itemID = "ItemID"
			case quantity = "Quantity"
		}
	}
}

public protocol _UntypedItem {
	var itemTypeID: ItemType.ID { get }
	var itemID: LowercaseUUID { get }
}

public extension _UntypedItem {
	var agent: Agent.ID? { typed() }
	var card: PlayerCard.ID? { typed() }
	var title: PlayerTitle.ID? { typed() }
	var skinLevel: Weapon.Skin.Level.ID? { typed() }
	var skinChroma: Weapon.Skin.Chroma.ID? { typed() }
	var spray: Spray.ID? { typed() }
	var buddy: Weapon.Buddy.Level.ID? { typed() }
	
	func typed<Item: InventoryItem>(as _: Item.Type = Item.self) -> Item.ID? {
		itemTypeID == Item.typeID ? .init(rawID: itemID) : nil
	}
}

public struct StoreWallet: Codable {
	@StringKeyedDictionary
	public var balances: [Currency.ID: Int]
	
	public subscript(id: Currency.ID) -> Int {
		balances[id] ?? 0
	}
	
	private enum CodingKeys: String, CodingKey {
		case balances = "Balances"
	}
}

public enum Currency {
	public typealias ID = ObjectID<Self, LowercaseUUID>
}

public extension Currency.ID {
	static let valorantPoints = Self("85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741")!
	static let radianitePoints = Self("e59aa87c-4cbf-517a-5983-6e81511be9b7")!
	static let freeAgents = Self("f08d4ae3-939c-4576-ab26-09ce1f23bb37")!
}
