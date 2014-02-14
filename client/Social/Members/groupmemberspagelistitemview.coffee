class GroupMembersPageListItemView extends MembersListItemView
  constructor : (options = {}, data) ->
    options.cssClass     = "clearfix"
    options.avatar       =
      size               :
        width            : 50
        height           : 50

    super options, data

    @followButton = new FollowButton
      style          : "solid green medium"
      title          : "follow"
      cssClass       : "follow-button"
      stateOptions   :
        following    :
          title      : "following"
          style      : "solid light-gray medium"
        unfollow     :
          title      : "unfollow"
          style      : "solid red medium"
      dataType       : 'JAccount'
    , data

    @followButton.unsetClass 'follow-btn'
