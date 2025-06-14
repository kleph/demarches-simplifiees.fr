# frozen_string_literal: true

describe Users::RegistrationsController, type: :controller do
  let(:email) { 'test@octo.com' }
  let(:password) { SECURE_PASSWORD }

  let(:user) { { email: email, password: password } }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe '#new' do
    subject { get :new }

    it { expect(subject).to have_http_status(:ok) }
    it { expect(subject).to render_template(:new) }

    context 'when an email address is provided' do
      render_views true
      subject { get :new, params: { user: { email: 'test@exemple.fr' } } }

      it 'prefills the form with the email address' do
        expect(subject.body).to include('test@exemple.fr')
      end
    end

    context 'when a procedure location has been stored' do
      let(:procedure) { create :procedure, :published }

      before do
        controller.store_location_for(:user, commencer_path(path: procedure.path))
      end

      it 'makes the saved procedure available' do
        expect(subject.status).to eq 200
        expect(assigns(:procedure)).to eq procedure
      end
    end
  end

  describe '#create' do
    subject do
      post :create, params: { user: user }
    end

    before do
      allow(Current).to receive(:host).and_return(ENV.fetch("APP_HOST"))
      Flipper.enable(:switch_domain)
    end

    after do
      Flipper.disable(:switch_domain)
    end

    context 'when user is correct' do
      it 'sends confirmation instruction' do
        message = double()
        expect(DeviseUserMailer).to receive(:confirmation_instructions).and_return(message)
        expect(message).to receive(:deliver_later)

        subject

        expect(User.last.preferred_domain_demarches_numerique_gouv_fr?).to be_truthy
      end
    end

    context 'when user is not correct' do
      let(:user) { { email: '', password: password } }

      it 'not sends confirmation instruction' do
        expect(DeviseUserMailer).not_to receive(:confirmation_instructions)

        subject
      end
    end

    context 'when the user already exists' do
      let!(:existing_user) { create(:user, email: email, password: password, confirmed_at: confirmed_at) }

      before do
        allow(UserMailer).to receive(:new_account_warning).and_return(double(deliver_later: 'deliver'))
      end

      context 'and the user is confirmed' do
        let(:confirmed_at) { Time.zone.now }

        before { subject }

        it 'sends an email to the user, stating that the account already exists' do
          expect(UserMailer).to have_received(:new_account_warning)
        end

        it 'avoids leaking information about the account existence, by redirecting to the same page than normal signup' do
          expect(response).to redirect_to(new_user_confirmation_path(user: { email: user[:email] }))
        end
      end

      context 'and the user is not confirmed' do
        let(:confirmed_at) { nil }

        before do
          expect_any_instance_of(User).to receive(:resend_confirmation_instructions)
          subject
        end

        it 'does not send a warning email' do
          expect(UserMailer).not_to have_received(:new_account_warning)
        end

        it 'avoids leaking information about the account existence, by redirecting to the same page than normal signup' do
          expect(response).to redirect_to(new_user_confirmation_path(user: { email: user[:email] }))
        end
      end
    end
  end
end
