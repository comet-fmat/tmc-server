require 'spec_helper'

describe Exercise do
  include GitTestActions
  
  let(:user) { Factory.create(:user) }
  let(:course) { Factory.create(:course) }

  describe "when read from a course repo" do
    before :each do
      @course_name = 'MyCourse'
      FileUtils.mkdir_p 'bare_repo'
      copy_model_repo("bare_repo/#{@course_name}")
      system! "git clone -q bare_repo/#{@course_name} #{@course_name}"
      @repo = GitRepo.new(@course_name)
    end
    
    it "should find all exercise names" do
      @repo.copy_simple_exercise('Ex1')
      @repo.copy_simple_exercise('Ex2')
      @repo.add_commit_push
      
      exercise_names = Exercise.read_exercise_names(@course_name)
      exercise_names.length.should == 2
      
      exercise_names.sort!
      exercise_names[0].should == 'Ex1'
      exercise_names[1].should == 'Ex2'
    end
    
    # TODO: should test metadata loading, but tests for Course.refresh already test that.
    # Some more mocking should probably happen somewhere..
    
  end
  
  
  describe "associated submissions" do
    before :each do
      @exercise = Exercise.create!(:course => course, :name => 'MyExercise')
      @submission_attrs = {
        :course => course,
        :exercise_name => 'MyExercise',
        :user => user,
        :skip_test_runner => true
      }
      Submission.create!(@submission_attrs)
      Submission.create!(@submission_attrs)
      @submissions = Submission.all
    end
    
    it "should be associated by exercise name" do
      @exercise.submissions.size.should == 2
      @submissions[0].exercise.should == @exercise
      @submissions[0].exercise_name = 'AnotherExercise'
      @submissions[0].save!
      @exercise.submissions.size.should == 1
    end
  end
  
  it "should treat date deadlines as being at 23:59:59 local time" do
    ex = Exercise.create!(:course => course, :name => 'MyExercise')
    ex.deadline = Date.today
    ex.deadline.should == Date.today.end_of_day
  end
  
  it "should accept deadlines in either SQLish or Finnish date format" do
    ex = Exercise.create!(:course => course, :name => 'MyExercise')
    
    ex.deadline = '2011-04-19 13:55'
    ex.deadline.year.should == 2011
    ex.deadline.month.should == 04
    ex.deadline.day.should == 19
    ex.deadline.hour.should == 13
    ex.deadline.min.should == 55
    
    ex.deadline = '25.05.2012 14:56'
    ex.deadline.day.should == 25
    ex.deadline.month.should == 5
    ex.deadline.year.should == 2012
    ex.deadline.hour.should == 14
    ex.deadline.min.should == 56
  end
  
  it "should accept a blank deadline" do
    ex = Exercise.create!(:course => course, :name => 'MyExercise')
    ex.deadline = nil
    ex.deadline.should be_nil
    ex.deadline = ""
    ex.deadline.should be_nil
  end
  
  it "should raise an exception if trying to set a deadline in invalid format" do
    ex = Factory.create(:exercise)
    expect { ex.deadline = "xooxers" }.to raise_error
    expect { ex.deadline = "2011-07-13 12:34:56:78" }.to raise_error
  end
  
  it "should always be available to administrators" do
    admin = Factory.create(:admin)
    ex = Exercise.create!(:course => course, :name => 'MyExercise')
    
    ex.deadline.should be_nil
    ex.should be_available_to(admin)
    
    ex.deadline = Date.today - 1.day
    ex.should be_available_to(admin)
  end
  
  it "should be available to non-administrators only if the deadline has not passed" do
    user = Factory.create(:user)
    ex = Exercise.create!(:course => course, :name => 'MyExercise')
    
    ex.deadline.should be_nil
    ex.should be_available_to(user)
    
    ex.deadline = Date.today + 1.day
    ex.should be_available_to(user)
    
    ex.deadline = Date.today - 1.day
    ex.should_not be_available_to(user)
  end
  
  it "can tell whether a user has ever attempted an exercise" do
    exercise = Exercise.new(:course => course, :name => 'MyExercise')
    exercise.should_not be_attempted_by(user)
    
    Submission.create!(:user => user, :course => course, :exercise_name => exercise.name)
    exercise.should be_attempted_by(user)
  end
  
  it "can tell whether a user has completed an exercise" do
    exercise = Exercise.new(:course => course, :name => 'MyExercise')
    exercise.should_not be_completed_by(user)
    
    other_user = Factory.create(:user)
    other_user_sub = Submission.create!(:user => other_user, :course => course, :exercise_name => exercise.name)
    other_user_sub.test_case_runs.create!(:test_case_name => 'one', :successful => true)
    other_user_sub.test_case_runs.create!(:test_case_name => 'two', :successful => true)
    exercise.should_not be_completed_by(user)
    
    Submission.create!(:user => user, :course => course, :exercise_name => exercise.name, :pretest_error => 'oops')
    exercise.should_not be_completed_by(user)
    
    sub = Submission.create!(:user => user, :course => course, :exercise_name => exercise.name)
    tcr1 = sub.test_case_runs.create!(:test_case_name => 'one', :successful => true)
    tcr2 = sub.test_case_runs.create!(:test_case_name => 'one', :successful => false)
    exercise.should_not be_completed_by(user)

    tcr2.successful = true
    tcr2.save!
    exercise.should be_completed_by(user)
  end
end

