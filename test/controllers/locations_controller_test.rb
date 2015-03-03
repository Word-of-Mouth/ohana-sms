require 'test_helper'

class LocationsControllerTest < ActionController::TestCase
  test 'should get reply' do
    get_reply_with_body('foo')
    assert_response :success
  end

  test 'sends a Twilio::TwiML::Response' do
    twiml = Twilio::TwiML::Response.new { |r| r.Message 'foo' }
    Twilio::TwiML::Response.expects(:new).returns(twiml)
    assert get_reply_with_body('boo')
  end

  test 'increments session counter by one' do
    get_reply_with_body('foo')
    assert_equal 1, session[:counter]
  end

  test 'asks for valid zip when body is empty' do
    get_reply_with_body('')
    assert_equal t('intro'), sms_body
  end

  test 'keeps asking for valid zip until body matches 5 digits' do
    get_reply_with_body('')
    get_reply_with_body('foo')
    assert_equal t('intro'), sms_body
  end

  test 'asks for valid zip when body is not 5 digits' do
    get_reply_with_body('foo')
    assert_equal t('intro'), sms_body
  end

  test 'asks for category choice when body matches 5 digits' do
    get_reply_with_body('94103')
    assert_match(/Please choose a category/, sms_body)
  end

  test 'returns numbered categories when body matches 5 digits' do
    get_reply_with_body('94103')
    assert_match(/#1: Care/, sms_body)
  end

  test 'asks for category when body matches 5 digits after initial SMS' do
    get_reply_with_body('foo')
    get_reply_with_body('94103')
    assert_match(/Please choose a category/, sms_body)
  end

  test 'sets session[:zip] to the body when body matches 5 digits' do
    get_reply_with_body('94103')
    assert_equal '94103', session[:zip]
  end

  test 'sets session[:step_2] to true when body matches 5 digits' do
    get_reply_with_body('94103')
    assert_equal true, session[:step_2]
  end

  test 'asks for number when session[:step_2] is true & body is not 1-11' do
    get_reply_with_body('94103')
    get_reply_with_body('foo')
    assert_equal 'Please enter a number between 1 and 11', sms_body
  end

  test 'asks for number when session[:step_2] is true & number out of range' do
    get_reply_with_body('94103')
    get_reply_with_body('12')
    assert_equal 'Please enter a number between 1 and 11', sms_body
  end

  test 'returns 5 locations when category choice is 1-11' do
    get_reply_with_body('94103')
    get_reply_with_body('11')
    assert_match(/Here are 5 locations/, sms_body)
  end

  test 'does not duplicate location and org name if equal' do
    get_reply_with_body('94103')
    get_reply_with_body('3')
    refute_match(/Breast Cancer Emergency Fund \(Breast Cancer Emergency Fund\)/, sms_body)
  end

  test 'returns helpful message when no results are found' do
    get_reply_with_body('94388')
    get_reply_with_body('11')
    assert_equal 'Sorry, no results found.', sms_body
  end

  test 'resets conversation when no results are found' do
    get_reply_with_body('94388')
    get_reply_with_body('11')
    assert_equal false, session[:step_2]
    assert_equal false, session[:step_3]
    assert_equal 1, session[:counter]
  end

  test 'sets session[:step_3] to true when category is 1-11' do
    get_reply_with_body('94103')
    get_reply_with_body('2')
    assert_equal true, session[:step_3]
  end

  test 'sets session[:cats] to body when category is 1-11' do
    get_reply_with_body('94103')
    get_reply_with_body('2')
    assert_equal '2', session[:cats]
  end

  test 'sets session[:step_2] to false when category is 1-11' do
    get_reply_with_body('94103')
    get_reply_with_body('2')
    assert_equal false, session[:step_2]
  end

  test 'returns location details when location choice is 1-5' do
    get_reply_with_body('94103')
    get_reply_with_body('4')
    get_reply_with_body('1')
    assert_match(/Phone:/, sms_body)
  end

  test 'asks for valid choice when body is not 1-5' do
    get_reply_with_body('94103')
    get_reply_with_body('4')
    get_reply_with_body('6')
    assert_equal t('choose_location'), sms_body
  end

  test 'leaves session[:step_2] set to false when location is 1-5' do
    get_reply_with_body('94103')
    get_reply_with_body('2')
    get_reply_with_body('4')
    assert_equal false, session[:step_2]
  end

  test 'leaves session[:step_3] set to true when location is 1-5' do
    get_reply_with_body('94103')
    get_reply_with_body('2')
    get_reply_with_body('4')
    assert_equal true, session[:step_3]
  end

  test 'sets session[:location] to body when location is 1-5' do
    get_reply_with_body('94103')
    get_reply_with_body('2')
    get_reply_with_body('4')
    assert_equal '4', session[:location]
  end

  test 'resets session[:counter] to 0 when body = reset' do
    get_reply_with_body('94103')
    get_reply_with_body('reset')
    assert_equal 1, session[:counter]
  end

  test 'resets session[:counter] to 0 when body = Reset' do
    get_reply_with_body('94103')
    get_reply_with_body('Reset')
    assert_equal 1, session[:counter]
  end

  test 'does not reset session[:counter] when body is not exactly /reset/i' do
    get_reply_with_body('94103')
    get_reply_with_body('resetz')
    assert_equal 2, session[:counter]
  end

  test 'asks for a location number if the conversation is not reset' do
    get_reply_with_body('94103')
    get_reply_with_body('2')
    get_reply_with_body('3')
    get_reply_with_body('foo')
    assert_equal t('choose_location'), sms_body
  end

  test 'returns details for different location when new number is entered' do
    get_reply_with_body('94103')
    get_reply_with_body('2')
    get_reply_with_body('3')
    first_phone = sms_body.delete('^0-9')
    get_reply_with_body('5')
    second_phone = sms_body.delete('^0-9')
    refute_equal first_phone, second_phone
  end

  test 'resets the conversation if interrupted before the end' do
    get_reply_with_body('94103')
    get_reply_with_body('reset')
    assert_equal t('intro'), sms_body
  end

  test 'sets session[:step_2] to false when the conversation is finished' do
    get_reply_with_body('94103')
    get_reply_with_body('2')
    assert_equal false, session[:step_2]
  end

  test 'sets session[:step_2] to false when the conversation is reset' do
    get_reply_with_body('94103')
    get_reply_with_body('reset')
    assert_equal false, session[:step_2]
  end

  test 'tracks conversation from beginning to end' do
    get_reply_with_body('hi')
    get_reply_with_body('94103')
    get_reply_with_body('hi')
    get_reply_with_body('2')
    get_reply_with_body('5')
    assert_match(/Phone:/, sms_body)
  end

  test 'tracks conversation after reset' do
    get_reply_with_body('hi')
    get_reply_with_body('94103')
    get_reply_with_body('hello')
    get_reply_with_body('reset')
    get_reply_with_body('foo')
    assert_equal t('intro'), sms_body
  end

  private

  def get_reply_with_body(body)
    get :reply, 'Body' => body
  end
end
