"""
Sample Data Generator for SaaS Subscription Analytics Project
Generates realistic customer, subscription, and marketing data for CloudSync Pro
"""

import csv
import random
from datetime import datetime, timedelta
from typing import List, Dict, Tuple
import hashlib

# Set seed for reproducibility
random.seed(42)

# Configuration
START_DATE = datetime(2023, 1, 1)
END_DATE = datetime(2024, 12, 31)
NUM_CUSTOMERS = 750

# Plan distribution (weighted towards lower tiers, realistic SaaS)
PLANS = {
    1: {'name': 'Starter', 'price': 0, 'weight': 0.25},
    2: {'name': 'Pro', 'price': 29, 'weight': 0.40},
    3: {'name': 'Team', 'price': 79, 'weight': 0.25},
    4: {'name': 'Enterprise', 'price': 199, 'weight': 0.10}
}

# Channel distribution with conversion tendencies
CHANNELS = {
    1: {'name': 'google_ads', 'weight': 0.20, 'quality': 0.7},
    2: {'name': 'facebook_ads', 'weight': 0.12, 'quality': 0.5},
    3: {'name': 'linkedin_ads', 'weight': 0.08, 'quality': 0.8},
    4: {'name': 'organic_search', 'weight': 0.18, 'quality': 0.75},
    5: {'name': 'direct', 'weight': 0.15, 'quality': 0.65},
    6: {'name': 'referral', 'weight': 0.10, 'quality': 0.85},
    7: {'name': 'content_marketing', 'weight': 0.08, 'quality': 0.7},
    8: {'name': 'email_campaign', 'weight': 0.05, 'quality': 0.6},
    9: {'name': 'partner', 'weight': 0.03, 'quality': 0.8},
    10: {'name': 'webinar', 'weight': 0.01, 'quality': 0.9}
}

# Industries for B2B context
INDUSTRIES = [
    'Technology', 'Healthcare', 'Finance', 'Retail', 'Manufacturing',
    'Education', 'Media', 'Real Estate', 'Legal', 'Consulting',
    'Marketing', 'Non-Profit', 'Government', 'Transportation', 'Energy'
]

COMPANY_SIZES = ['1-10', '11-50', '51-200', '201-500', '501-1000', '1000+']

def generate_customer_id() -> str:
    return f"cust_{random.randint(100000, 999999)}"

def generate_subscription_id() -> str:
    return f"sub_{random.randint(100000, 999999)}"

def generate_event_id() -> str:
    return f"evt_{random.randint(1000000, 9999999)}"

def generate_payment_id() -> str:
    return f"pay_{random.randint(1000000, 9999999)}"

def generate_touch_id() -> str:
    return f"touch_{random.randint(1000000, 9999999)}"

def weighted_choice(options: Dict) -> int:
    choices = list(options.keys())
    weights = [options[k]['weight'] for k in choices]
    return random.choices(choices, weights=weights)[0]

def random_date(start: datetime, end: datetime) -> datetime:
    delta = end - start
    random_days = random.randint(0, delta.days)
    return start + timedelta(days=random_days)

def generate_email(company_name: str, domain_num: int) -> str:
    prefixes = ['info', 'contact', 'admin', 'hello', 'team', 'support']
    domains = ['company', 'corp', 'inc', 'co', 'io', 'tech']
    return f"{random.choice(prefixes)}@{company_name.lower().replace(' ', '')}{domain_num}.{random.choice(domains)}"

def generate_customers() -> List[Dict]:
    """Generate customer records"""
    customers = []
    
    for i in range(NUM_CUSTOMERS):
        customer_id = generate_customer_id()
        signup_date = random_date(START_DATE, END_DATE - timedelta(days=30))
        
        # Company size affects plan choice
        company_size = random.choice(COMPANY_SIZES)
        size_idx = COMPANY_SIZES.index(company_size)
        
        # Larger companies more likely to pick higher tiers
        if size_idx >= 4:  # 501+
            plan_weights = {1: 0.05, 2: 0.15, 3: 0.40, 4: 0.40}
        elif size_idx >= 2:  # 51-500
            plan_weights = {1: 0.10, 2: 0.35, 3: 0.40, 4: 0.15}
        else:  # 1-50
            plan_weights = {1: 0.35, 2: 0.45, 3: 0.15, 4: 0.05}
        
        initial_plan = random.choices(list(plan_weights.keys()), 
                                       weights=list(plan_weights.values()))[0]
        
        acquisition_channel = weighted_choice(CHANNELS)
        
        customers.append({
            'customer_id': customer_id,
            'company_name': f"Company_{i+1}",
            'industry': random.choice(INDUSTRIES),
            'company_size': company_size,
            'country': random.choices(
                ['US', 'UK', 'CA', 'DE', 'AU', 'FR', 'NL', 'SE', 'JP', 'BR'],
                weights=[0.45, 0.12, 0.10, 0.08, 0.07, 0.05, 0.04, 0.03, 0.03, 0.03]
            )[0],
            'signup_date': signup_date.strftime('%Y-%m-%d %H:%M:%S'),
            'email': generate_email(f"Company{i+1}", i),
            'acquisition_channel_id': acquisition_channel,
            'initial_plan_id': initial_plan,
            'is_trial': random.random() < 0.6,  # 60% start with trial
            'trial_end_date': (signup_date + timedelta(days=14)).strftime('%Y-%m-%d') if random.random() < 0.6 else None
        })
    
    return customers

def generate_subscriptions_and_events(customers: List[Dict]) -> Tuple[List[Dict], List[Dict]]:
    """Generate subscription records and lifecycle events"""
    subscriptions = []
    events = []
    
    for customer in customers:
        customer_id = customer['customer_id']
        signup_date = datetime.strptime(customer['signup_date'], '%Y-%m-%d %H:%M:%S')
        current_plan = customer['initial_plan_id']
        is_trial = customer['is_trial']
        
        # Create initial subscription
        sub_id = generate_subscription_id()
        sub_start = signup_date
        
        # Determine subscription lifecycle
        channel_quality = CHANNELS[customer['acquisition_channel_id']]['quality']
        
        # Base churn probability (modified by channel quality and plan)
        base_churn_prob = 0.15 - (channel_quality * 0.05) - (current_plan * 0.02)
        
        # Track MRR for this subscription
        current_mrr = PLANS[current_plan]['price']
        billing_cycle = random.choices(['monthly', 'annual'], weights=[0.7, 0.3])[0]
        
        # Initial subscription event
        events.append({
            'event_id': generate_event_id(),
            'subscription_id': sub_id,
            'customer_id': customer_id,
            'event_type': 'subscription_started',
            'event_date': sub_start.strftime('%Y-%m-%d %H:%M:%S'),
            'plan_id': current_plan,
            'mrr_change': current_mrr,
            'mrr_after': current_mrr
        })
        
        # Simulate subscription lifecycle
        current_date = sub_start
        is_active = True
        sub_end = None
        
        while current_date < END_DATE and is_active:
            # Move forward 1-3 months
            days_forward = random.randint(25, 90)
            current_date += timedelta(days=days_forward)
            
            if current_date >= END_DATE:
                break
            
            # Determine what happens
            roll = random.random()
            
            if roll < base_churn_prob:
                # Churn
                is_active = False
                sub_end = current_date
                events.append({
                    'event_id': generate_event_id(),
                    'subscription_id': sub_id,
                    'customer_id': customer_id,
                    'event_type': 'subscription_churned',
                    'event_date': current_date.strftime('%Y-%m-%d %H:%M:%S'),
                    'plan_id': current_plan,
                    'mrr_change': -current_mrr,
                    'mrr_after': 0
                })
                
                # Some customers reactivate
                if random.random() < 0.15:
                    reactivate_date = current_date + timedelta(days=random.randint(30, 180))
                    if reactivate_date < END_DATE:
                        # New subscription
                        sub_id = generate_subscription_id()
                        current_plan = max(1, current_plan - 1)  # Often come back at lower tier
                        current_mrr = PLANS[current_plan]['price']
                        is_active = True
                        sub_end = None
                        current_date = reactivate_date
                        
                        events.append({
                            'event_id': generate_event_id(),
                            'subscription_id': sub_id,
                            'customer_id': customer_id,
                            'event_type': 'subscription_reactivated',
                            'event_date': current_date.strftime('%Y-%m-%d %H:%M:%S'),
                            'plan_id': current_plan,
                            'mrr_change': current_mrr,
                            'mrr_after': current_mrr
                        })
                        
            elif roll < base_churn_prob + 0.08 and current_plan < 4:
                # Upgrade
                old_plan = current_plan
                old_mrr = current_mrr
                current_plan = min(4, current_plan + 1)
                current_mrr = PLANS[current_plan]['price']
                
                events.append({
                    'event_id': generate_event_id(),
                    'subscription_id': sub_id,
                    'customer_id': customer_id,
                    'event_type': 'subscription_upgraded',
                    'event_date': current_date.strftime('%Y-%m-%d %H:%M:%S'),
                    'plan_id': current_plan,
                    'mrr_change': current_mrr - old_mrr,
                    'mrr_after': current_mrr
                })
                
            elif roll < base_churn_prob + 0.12 and current_plan > 1:
                # Downgrade
                old_plan = current_plan
                old_mrr = current_mrr
                current_plan = max(1, current_plan - 1)
                current_mrr = PLANS[current_plan]['price']
                
                events.append({
                    'event_id': generate_event_id(),
                    'subscription_id': sub_id,
                    'customer_id': customer_id,
                    'event_type': 'subscription_downgraded',
                    'event_date': current_date.strftime('%Y-%m-%d %H:%M:%S'),
                    'plan_id': current_plan,
                    'mrr_change': current_mrr - old_mrr,
                    'mrr_after': current_mrr
                })
        
        # Record final subscription state
        subscriptions.append({
            'subscription_id': sub_id,
            'customer_id': customer_id,
            'plan_id': current_plan,
            'status': 'active' if is_active else 'churned',
            'billing_cycle': billing_cycle,
            'mrr': current_mrr if is_active else 0,
            'start_date': sub_start.strftime('%Y-%m-%d'),
            'end_date': sub_end.strftime('%Y-%m-%d') if sub_end else None,
            'created_at': sub_start.strftime('%Y-%m-%d %H:%M:%S'),
            'updated_at': (sub_end or END_DATE).strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return subscriptions, events

def generate_payments(subscriptions: List[Dict], events: List[Dict]) -> List[Dict]:
    """Generate payment records based on subscriptions"""
    payments = []
    
    for sub in subscriptions:
        if sub['mrr'] == 0 and sub['status'] == 'churned':
            # Get events for this subscription to find active period
            sub_events = [e for e in events if e['subscription_id'] == sub['subscription_id']]
            if not sub_events:
                continue
        
        start = datetime.strptime(sub['start_date'], '%Y-%m-%d')
        end = datetime.strptime(sub['end_date'], '%Y-%m-%d') if sub['end_date'] else END_DATE
        
        # Get MRR history from events
        sub_events = sorted(
            [e for e in events if e['subscription_id'] == sub['subscription_id']],
            key=lambda x: x['event_date']
        )
        
        current_date = start
        current_mrr = 0
        
        for event in sub_events:
            current_mrr = event['mrr_after']
        
        # Generate monthly payments
        payment_date = start
        while payment_date < end:
            # Find MRR at this point
            active_mrr = 0
            for event in sub_events:
                event_date = datetime.strptime(event['event_date'], '%Y-%m-%d %H:%M:%S')
                if event_date <= payment_date:
                    active_mrr = event['mrr_after']
            
            if active_mrr > 0:
                # Determine payment amount based on billing cycle
                if sub['billing_cycle'] == 'annual' and payment_date.month == start.month:
                    amount = active_mrr * 10  # Annual discount
                else:
                    amount = active_mrr
                
                # Small chance of failed payment
                status = 'succeeded' if random.random() > 0.03 else 'failed'
                
                payments.append({
                    'payment_id': generate_payment_id(),
                    'subscription_id': sub['subscription_id'],
                    'customer_id': sub['customer_id'],
                    'amount': round(amount, 2),
                    'currency': 'USD',
                    'payment_date': payment_date.strftime('%Y-%m-%d'),
                    'payment_method': random.choice(['credit_card', 'credit_card', 'credit_card', 'ach', 'wire']),
                    'status': status,
                    'created_at': payment_date.strftime('%Y-%m-%d %H:%M:%S')
                })
            
            # Next month (handle day overflow)
            if payment_date.month == 12:
                payment_date = payment_date.replace(year=payment_date.year + 1, month=1, day=1)
            else:
                payment_date = payment_date.replace(month=payment_date.month + 1, day=1)
    
    return payments

def generate_marketing_touches(customers: List[Dict]) -> List[Dict]:
    """Generate marketing touchpoints leading to conversion"""
    touches = []
    
    for customer in customers:
        customer_id = customer['customer_id']
        signup_date = datetime.strptime(customer['signup_date'], '%Y-%m-%d %H:%M:%S')
        primary_channel = customer['acquisition_channel_id']
        
        # Generate 1-8 touchpoints before conversion
        num_touches = random.randint(1, 8)
        
        # First touch is 7-60 days before signup
        first_touch_date = signup_date - timedelta(days=random.randint(7, 60))
        
        for i in range(num_touches):
            # Distribute touches between first touch and signup
            if num_touches == 1:
                touch_date = first_touch_date
            else:
                days_range = (signup_date - first_touch_date).days
                touch_offset = int((i / (num_touches - 1)) * days_range) if num_touches > 1 else 0
                touch_date = first_touch_date + timedelta(days=touch_offset)
            
            # First and last touch more likely to be primary channel
            if i == 0 or i == num_touches - 1:
                channel = primary_channel if random.random() < 0.7 else weighted_choice(CHANNELS)
            else:
                channel = weighted_choice(CHANNELS)
            
            touches.append({
                'touch_id': generate_touch_id(),
                'customer_id': customer_id,
                'channel_id': channel,
                'touch_date': touch_date.strftime('%Y-%m-%d %H:%M:%S'),
                'touch_type': random.choice(['visit', 'click', 'form_submit', 'content_download', 'demo_request']),
                'landing_page': random.choice(['/home', '/pricing', '/features', '/demo', '/blog', '/case-studies']),
                'utm_campaign': f"campaign_{random.randint(1, 50)}" if CHANNELS[channel]['name'].endswith('_ads') else None,
                'conversion_date': signup_date.strftime('%Y-%m-%d %H:%M:%S')
            })
    
    return touches

def write_csv(data: List[Dict], filepath: str):
    """Write data to CSV file"""
    if not data:
        return
    
    with open(filepath, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=data[0].keys())
        writer.writeheader()
        writer.writerows(data)
    
    print(f"Written {len(data)} records to {filepath}")

def main():
    print("Generating CloudSync Pro sample data...")
    
    # Generate data
    print("\n1. Generating customers...")
    customers = generate_customers()
    
    print("2. Generating subscriptions and events...")
    subscriptions, events = generate_subscriptions_and_events(customers)
    
    print("3. Generating payments...")
    payments = generate_payments(subscriptions, events)
    
    print("4. Generating marketing touches...")
    marketing_touches = generate_marketing_touches(customers)
    
    # Write to CSV files
    print("\n5. Writing CSV files...")
    base_path = '/home/claude/github-portfolio/saas-subscription-analytics/data/raw'
    
    write_csv(customers, f"{base_path}/customers.csv")
    write_csv(subscriptions, f"{base_path}/subscriptions.csv")
    write_csv(events, f"{base_path}/subscription_events.csv")
    write_csv(payments, f"{base_path}/payments.csv")
    write_csv(marketing_touches, f"{base_path}/marketing_touches.csv")
    
    # Print summary stats
    print("\n=== Data Summary ===")
    print(f"Customers: {len(customers)}")
    print(f"Subscriptions: {len(subscriptions)}")
    print(f"Subscription Events: {len(events)}")
    print(f"Payments: {len(payments)}")
    print(f"Marketing Touches: {len(marketing_touches)}")
    
    active_subs = len([s for s in subscriptions if s['status'] == 'active'])
    churned_subs = len([s for s in subscriptions if s['status'] == 'churned'])
    print(f"\nActive Subscriptions: {active_subs}")
    print(f"Churned Subscriptions: {churned_subs}")
    print(f"Churn Rate: {churned_subs / len(subscriptions) * 100:.1f}%")
    
    total_mrr = sum(s['mrr'] for s in subscriptions if s['status'] == 'active')
    print(f"Current MRR: ${total_mrr:,.2f}")

if __name__ == "__main__":
    main()
